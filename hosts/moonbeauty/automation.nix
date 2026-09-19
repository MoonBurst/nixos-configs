{ config, pkgs, lib, ... }:

let
  # =========================================================================
  # 1. HARDWARE MEMORY BUDGETS & VRAM/RAM OFFLOADING
  # =========================================================================

  vramBudgetGB = 17;
  systemRamBudgetGB = 20;

  # All 64 model layers on 7900 XTX (full GPU acceleration)
  gpuLayers = 99;

  # 32,768 token context window (~25,000 words / 2,000+ lines of code)
  maxContextTokens = 32768;

  sandboxCpuLimit = "4";
  sandboxMemoryLimit = "${toString systemRamBudgetGB}g";
  pidsLimit = 250;

  # =========================================================================
  # 2. MODEL & PATH CONFIGURATION (32B Q3_K_M)
  # =========================================================================

  modelDir = "/home/agent/models";
  targetModel = "qwen2.5-coder-32b-instruct-q3_k_m.gguf";
  modelUrl =
    "https://huggingface.co/bartowski/"
    + "Qwen2.5-Coder-32B-Instruct-GGUF/resolve/main/"
    + "Qwen2.5-Coder-32B-Instruct-Q4_K_M.gguf";

  allowedMounts = [
    {
      hostPath = "/home/agent/workspace";
      mountPath = "/workspace";
      mode = "rw";
    }
  ];

  workDir = "/workspace";

  # =========================================================================
  # 3. CONTAINER IMAGE & HOST DEPENDENCIES
  # =========================================================================

  sandboxImage = pkgs.dockerTools.buildLayeredImage {
    name = "agent-sandbox";
    tag = "latest";
    contents = with pkgs; [
      bashInteractive
      coreutils
      findutils
      gnugrep
      gnused
      curl
      git
      python3
      nix
      jq
      bc
    ];
    config = {
      WorkingDir = workDir;
      Env = [
        "PATH=/bin"
        "LANG=en_US.UTF-8"
      ];
    };
  };

  agentPython = pkgs.python3.withPackages (ps: with ps; [
    openai
    ddgs
    beautifulsoup4
    requests
    pydantic
  ]);

  llamaGpu = pkgs.llama-cpp.override {
    rocmSupport = true;
  };

  mountJson = builtins.toJSON allowedMounts;

  # =========================================================================
  # 4. AGENT WORKER (SAFE ROLLING HISTORY & 32K SUPPORT)
  # =========================================================================

  agentWorker = pkgs.writeScriptBin "agent-worker" ''#!${agentPython}/bin/python3
import os
import re
import sys
import time
import json
import signal
import hashlib
import subprocess
import argparse
import datetime
import requests
from openai import OpenAI
from bs4 import BeautifulSoup

os.umask(0o002)

try:
    from ddgs import DDGS
except ImportError:
    try:
        from duckduckgo_search import DDGS
    except ImportError:
        class DDGS:
            def text(self, *args, **kwargs):
                return []

SERVER_URL = "http://127.0.0.1:11434"
API_URL = f"{SERVER_URL}/v1"
MOUNTS = json.loads('${mountJson}')
WORK_DIR = "${workDir}"
HOST_WORKSPACE = "/home/agent/workspace"
STATE_FILE = os.path.join(HOST_WORKSPACE, ".agent_state.json")
CPU_LIMIT = "${sandboxCpuLimit}"
MEM_LIMIT = "${sandboxMemoryLimit}"
PIDS_LIMIT = ${toString pidsLimit}
IMAGE_TAR = "${sandboxImage}"

current_task = ""
current_messages = []
current_step = 1

def save_state():
    if not current_task or not current_messages:
        return
    state = {
        "task": current_task,
        "step": current_step,
        "messages": current_messages,
        "saved_at": datetime.datetime.now().isoformat()
    }
    with open(STATE_FILE, "w") as fp:
        json.dump(state, fp, indent=2)

def sigint_handler(sig, frame):
    print("\n" + "=" * 60)
    print("⏸️  PAUSE DETECTED: Checkpointing state to disk...")
    save_state()
    print("=" * 60)
    sys.exit(42)

signal.signal(signal.SIGINT, sigint_handler)

def get_workspace_snapshot():
    snapshot = {}
    if not os.path.exists(HOST_WORKSPACE):
        return snapshot
    for root, dirs, files in os.walk(HOST_WORKSPACE):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if f.startswith("."):
                continue
            p = os.path.join(root, f)
            rel = os.path.relpath(p, HOST_WORKSPACE)
            try:
                if not os.path.islink(p) and os.path.isfile(p):
                    with open(p, "rb") as fp:
                        snapshot[rel] = hashlib.sha256(fp.read()).hexdigest()
            except OSError:
                pass
    return snapshot

INITIAL_SNAPSHOT = get_workspace_snapshot()
CREATED_THIS_SESSION = set()

def update_created_files():
    current = get_workspace_snapshot()
    for f in current.keys():
        if f not in INITIAL_SNAPSHOT:
            CREATED_THIS_SESSION.add(f)

def ensure_podman_image():
    check = subprocess.run(
        ["${pkgs.podman}/bin/podman", "image", "exists", "agent-sandbox:latest"],
        capture_output=True
    )
    if check.returncode != 0:
        print("📦 Loading Nix sandbox container into Podman...")
        subprocess.run(
            ["${pkgs.podman}/bin/podman", "load", "-i", IMAGE_TAR],
            check=True
        )

def wait_for_server():
    print("⏳ Waiting for 7900 XTX to load model into VRAM...")
    while True:
        try:
            r = requests.get(f"{SERVER_URL}/health", timeout=2)
            if r.status_code == 200:
                print(" Model loaded on 7900 XTX! Beginning task...")
                return
        except requests.exceptions.RequestException:
            pass
        time.sleep(1)

def sandboxed_bash(command: str) -> str:
    deletion_cmds = ["rm ", "rmdir ", "unlink ", "shred "]
    if any(d in command for d in deletion_cmds):
        for pre_file in INITIAL_SNAPSHOT.keys():
            base = os.path.basename(pre_file)
            if pre_file in command or base in command:
                return (
                    f"BLOCKED BY SECURITY POLICY: You are forbidden from "
                    f"deleting pre-existing file '{pre_file}'. You may "
                    f"only delete temp files you created yourself. If this "
                    f"file should be deleted, add it to 'recommended_deletions'."
                )

    mount_args = []
    for m in MOUNTS:
        os.makedirs(m["hostPath"], exist_ok=True)
        mount_args.extend([
            "-v", f"{m['hostPath']}:{m['mountPath']}:{m['mode']}"
        ])

    podman_cmd = [
        "${pkgs.podman}/bin/podman", "run", "--rm",
        "--network=host",
        "--security-opt=no-new-privileges",
        "--cap-drop=ALL",
        f"--cpus={CPU_LIMIT}",
        f"--memory={MEM_LIMIT}",
        f"--pids-limit={PIDS_LIMIT}",
        "-w", WORK_DIR,
    ] + mount_args + [
        "agent-sandbox:latest",
        "bash", "-c", f"umask 002 && {command}"
    ]

    try:
        res = subprocess.run(
            podman_cmd, capture_output=True, text=True, timeout=120
        )
        update_created_files()
        output = res.stdout + res.stderr
        return (
            output if output.strip() else "(Command executed successfully)"
        )
    except subprocess.TimeoutExpired:
        return "Error: Command timed out after 120 seconds."
    except Exception as e:
        return f"Execution error: {str(e)}"

def check_for_empty_files():
    """Checks if created code files were touched but left with 0 bytes."""
    empty = []
    for root, dirs, files in os.walk(HOST_WORKSPACE):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if f.startswith(".") or f == "CHANGES.md":
                continue
            p = os.path.join(root, f)
            rel = os.path.relpath(p, HOST_WORKSPACE)
            try:
                if not os.path.islink(p) and os.path.isfile(p):
                    if rel not in INITIAL_SNAPSHOT and os.path.getsize(p) == 0:
                        empty.append(rel)
            except OSError:
                pass
    return empty

def write_changelog_report(task: str, summary: str, recs: list, instructions: str):
    final_snapshot = get_workspace_snapshot()
    created = []
    modified = []

    for p, h in final_snapshot.items():
        if p == "CHANGES.md":
            continue
        if p not in INITIAL_SNAPSHOT:
            created.append(p)
        elif INITIAL_SNAPSHOT[p] != h:
            modified.append(p)

    report = [
        "# Agent Execution Changelog & Instructions",
        f"**Timestamp:** {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"**Task:** {task}",
        "",
        "## Summary of Work",
        summary,
        "",
        "## Instructions & Usage Guide (README)",
        instructions if instructions else "No specific setup steps required.",
        "",
        "## File Changes",
        f"- **Files Created ({len(created)}):**",
    ]
    for f in created or ["None"]:
        report.append(f"  - `{f}`")

    report.append(f"- **Files Modified ({len(modified)}):**")
    for f in modified or ["None"]:
        report.append(f"  - `{f}`")

    report.append("")
    report.append("## Recommended Deletions (Requires Manual User Action)")
    if recs:
        for rec in recs:
            report.append(f"- `[RECOMMEND REMOVAL]` {rec}")
    else:
        report.append("- None")

    report_path = os.path.join(HOST_WORKSPACE, "CHANGES.md")
    with open(report_path, "w") as fp:
        fp.write("\n".join(report) + "\n")
    print(f"\n📋 Detailed audit report written to: {report_path}")

def web_search(query: str) -> str:
    try:
        return json.dumps(DDGS().text(query, max_results=5), indent=2)
    except Exception as e:
        return f"Search error: {str(e)}"

def fetch_url(url: str) -> str:
    try:
        headers = {"User-Agent": "Mozilla/5.0"}
        r = requests.get(url, timeout=15, headers=headers)
        soup = BeautifulSoup(r.text, 'html.parser')
        for s in soup(["script", "style"]):
            s.decompose()
        return soup.get_text(separator=' ', strip=True)[:3500]
    except Exception as e:
        return f"Failed to fetch {url}: {str(e)}"

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "sandboxed_bash",
            "description": "Execute bash in the Podman sandbox container.",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string"}},
                "required": ["command"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": "Search the internet for packages or info.",
            "parameters": {
                "type": "object",
                "properties": {"query": {"type": "string"}},
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "fetch_url",
            "description": "Read text content from a web URL.",
            "parameters": {
                "type": "object",
                "properties": {"url": {"type": "string"}},
                "required": ["url"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "complete_task",
            "description": "Signal that the goal is verified complete.",
            "parameters": {
                "type": "object",
                "properties": {
                    "summary": {
                        "type": "string",
                        "description": "Summary of work performed."
                    },
                    "instructions": {
                        "type": "string",
                        "description": "Step-by-step setup guide and README."
                    },
                    "recommended_deletions": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Files you recommend the user delete."
                    }
                },
                "required": ["summary", "instructions"]
            }
        }
    }
]

SYSTEM_PROMPT = (
    "You are an expert autonomous AI software engineer.\n"
    "CRITICAL RULES:\n"
    "1. WRITE TO /workspace/: You MUST write all project files into "
    "'/workspace/' (e.g. `cat << 'EOF' > /workspace/steamsale.nix`). "
    "NEVER write to '/home/user/', as only '/workspace/' persists!\n"
    "2. NIX SYNTAX TEST: To verify .nix files, run "
    "`nix-instantiate --parse /workspace/<file>.nix`. "
    "NEVER attempt `nixos-rebuild switch` inside the sandbox!\n"
    "3. WRITE REAL CODE: Do NOT just `touch` files. Write complete code.\n"
    "4. NO EARLY EXIT: Inspect tool output before calling complete_task.\n"
    "5. README: Provide full setup guide in the 'instructions' field."
)

def prune_old_messages(messages, force_aggressive=False):
    if len(messages) <= 8:
        return messages

    if force_aggressive:
        print("✂️ Context limit reached! Trimming older turns...")
        return [messages[0], messages[1]] + messages[-6:]

    if len(messages) > 16:
        for i in range(2, len(messages) - 6):
            m = messages[i]
            if isinstance(m, dict):
                if m.get("role") == "tool" and len(str(m.get("content", ""))) > 200:
                    m["content"] = "[Output pruned to save memory]"
                elif m.get("role") == "assistant" and len(str(m.get("content", ""))) > 300:
                    m["content"] = "[Previous reasoning steps archived]"
    return messages

def parse_tool_calls(msg):
    calls = []
    if getattr(msg, "tool_calls", None):
        for tc in msg.tool_calls:
            try:
                calls.append((tc.function.name, json.loads(tc.function.arguments), tc.id))
            except Exception:
                pass
        return calls

    content = getattr(msg, "content", "") or ""
    pattern = r'\{\s*"name"\s*:\s*"([^"]+)"\s*,\s*"arguments"\s*:\s*(\{.*?\})\s*\}'
    matches = re.findall(pattern, content, re.DOTALL)
    for name, arg_str in matches:
        try:
            calls.append((name, json.loads(arg_str), f"call_{int(time.time()*1000)}"))
        except Exception:
            pass
    return calls

def run_agent(task: str, resume: bool = False, max_steps: int = 50):
    global current_task, current_messages, current_step
    ensure_podman_image()
    wait_for_server()
    client = OpenAI(base_url=API_URL, api_key="local")

    if resume and os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as fp:
            state = json.load(fp)
        current_task = state["task"]
        current_step = state["step"]
        messages = state["messages"]
        print(f"▶️ Resuming task at Step {current_step}: '{current_task}'")
    else:
        current_task = task
        current_step = 1
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Task: {task}"}
        ]

    for step in range(current_step, max_steps + 1):
        current_step = step
        current_messages = messages
        print(f"\n[Step {step}/{max_steps}] Reasoning on 7900XTX (Press Ctrl+C to pause)...")
        messages = prune_old_messages(messages)

        try:
            response = client.chat.completions.create(
                model="qwen",
                messages=messages,
                tools=TOOLS,
                tool_choice="auto",
                temperature=0.1
            )
        except Exception as e:
            err_msg = str(e)
            print(f"Inference warning: {err_msg}")
            if "exceeds the available context size" in err_msg:
                messages = prune_old_messages(messages, force_aggressive=True)
                time.sleep(1)
                continue
            time.sleep(2)
            continue

        msg = response.choices[0].message
        messages.append(msg.model_dump())

        tool_calls = parse_tool_calls(msg)
        if not tool_calls:
            print(f"{msg.content}")
            messages.append({
                "role": "user",
                "content": (
                    "Proceed with the next tool call or complete_task."
                )
            })
            continue

        has_bash = any(c[0] == "sandboxed_bash" for c in tool_calls)
        if has_bash and any(c[0] == "complete_task" for c in tool_calls):
            tool_calls = [c for c in tool_calls if c[0] != "complete_task"]

        for name, args, call_id in tool_calls:
            print(f"Action: {name} -> {args}")

            if name == "complete_task":
                empty = check_for_empty_files()
                if empty:
                    output = (
                        f"REJECTED: The following created files are EMPTY (0 bytes): "
                        f"{', '.join(empty)}. You MUST write the actual code into "
                        f"these files using `cat << 'EOF' > ...` and verify them!"
                    )
                    print(f"⚠️  {output}")
                    messages.append({
                        "role": "tool",
                        "tool_call_id": call_id,
                        "content": str(output)
                    })
                    continue

                summary = args.get("summary", "Done.")
                instructions = args.get("instructions", "")
                recs = args.get("recommended_deletions", [])
                print("\n" + "=" * 60)
                print("TASK COMPLETE")
                print("=" * 60)
                print(summary)
                print("=" * 60)
                write_changelog_report(current_task, summary, recs, instructions)
                if os.path.exists(STATE_FILE):
                    os.remove(STATE_FILE)
                return

            if name == "sandboxed_bash":
                output = sandboxed_bash(args.get("command", ""))
            elif name == "web_search":
                output = web_search(args.get("query", ""))
            elif name == "fetch_url":
                output = fetch_url(args.get("url", ""))
            else:
                output = f"Unknown tool: {name}"

            messages.append({
                "role": "tool",
                "tool_call_id": call_id,
                "content": str(output)
            })

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--task", type=str, required=False, default="")
    parser.add_argument("--resume", action="store_true", default=False)
    args = parser.parse_args()

    if not args.resume and not args.task:
        print("Error: Specify either --task '...' or --resume")
        sys.exit(1)

    run_agent(args.task, resume=args.resume)
  '';

  # User wrapper: interactive notify-send opens micro on CHANGES.md
  agent = pkgs.writeShellScriptBin "agent" ''
    STATE_FILE="/home/agent/workspace/.agent_state.json"
    CHANGES_FILE="/home/agent/workspace/CHANGES.md"

    cleanup() {
      systemctl --user stop llama-server
    }
    trap cleanup EXIT

    if [ "''${1:-}" = "--resume" ]; then
      if [ ! -f "$STATE_FILE" ]; then
        echo "❌ No paused task found to resume!"
        exit 1
      fi
      echo "▶️ Resuming task from checkpoint..."
    fi

    echo "🚀 Starting 7900 XTX inference server..."
    systemctl --user start llama-server

    cd /home/agent/workspace
    set +e
    sudo -u agent ${agentPython}/bin/python3 ${agentWorker}/bin/agent-worker "$@"
    EXIT_CODE=$?
    set -e

    if [ $EXIT_CODE -eq 42 ]; then
      echo ""
      echo "============================================================"
      echo "⏸️  TASK PAUSED — 100% VRAM RELEASED (0 MB USED)"
      echo "============================================================"
      echo "Your GPU is completely free for gaming, rendering, etc."
      echo ""
      echo "To resume later, run:   agent --resume"
      echo "Or press [Enter] to resume immediately..."
      read -r
      exec agent --resume
    elif [ $EXIT_CODE -eq 0 ]; then
      printf '\a\a\a'
      ACTION=$(${pkgs.libnotify}/bin/notify-send \
        -u critical \
        -A "open=Open in Micro" \
        "Agent Completed Task" \
        "Finished. Click 'Open in Micro' to read CHANGES.md") || true

      if [ "$ACTION" = "open" ]; then
        TERM_CMD=""
        if [ -n "''${TERMINAL:-}" ] && command -v "$TERMINAL" >/dev/null 2>&1; then
          TERM_CMD="$TERMINAL -e"
        elif command -v foot >/dev/null 2>&1; then
          TERM_CMD="foot -e"
        elif command -v kitty >/dev/null 2>&1; then
          TERM_CMD="kitty -e"
        elif command -v alacritty >/dev/null 2>&1; then
          TERM_CMD="alacritty -e"
        elif command -v xterm >/dev/null 2>&1; then
          TERM_CMD="xterm -e"
        fi

        if [ -n "$TERM_CMD" ]; then
          $TERM_CMD ${pkgs.micro}/bin/micro "$CHANGES_FILE" &
        else
          ${pkgs.micro}/bin/micro "$CHANGES_FILE"
        fi
      fi
    fi
  '';

  # Native GPU allocation for 32,768 tokens (no freezing -nkvo flag)
  startLlamaScript = pkgs.writeShellScript "start-llama-server" ''
    set -euo pipefail
    TARGET_PATH="${modelDir}/${targetModel}"

    if [ ! -f "$TARGET_PATH" ]; then
      echo "Model not found. Downloading Qwen2.5-Coder-32B Q3..."
      [ -d "${modelDir}" ] || mkdir -p "${modelDir}" 2>/dev/null || true
      ${pkgs.curl}/bin/curl -L -C - \
        -o "$TARGET_PATH.part" \
        "${modelUrl}"
      mv "$TARGET_PATH.part" "$TARGET_PATH"
      echo "Model download complete."
    fi

    exec ${llamaGpu}/bin/llama-server \
      -m "$TARGET_PATH" \
      --port 11434 \
      -c ${toString maxContextTokens} \
      -ngl ${toString gpuLayers} \
      --flash-attn on \
      --jinja \
      -np 1 \
      -b 512 \
      -ub 512 \
      --cache-type-k q4_0 \
      --cache-type-v q4_0 \
      --fit off
  '';
in
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # 1. User definitions and group sharing
  users.users.agent = {
    isNormalUser = true;
    home = "/home/agent";
    homeMode = "0775";
    createHome = true;
    group = "agent";
    description = "Sandboxed Autonomous Agent";
    extraGroups = [ "video" "render" ];
    subUidRanges = [
      { startUid = 100000; count = 65536; }
    ];
    subGidRanges = [
      { startGid = 100000; count = 65536; }
    ];
  };

  users.groups.agent.members = [ "moonburst" ];

  # 2. Declarative one-way directory permissions and ACLs
  systemd.tmpfiles.rules = [
    "z /home/agent 0775 agent agent -"
    "d /home/agent/models 2775 moonburst agent -"
    "z /home/agent/models 2775 moonburst agent -"
    "d /home/agent/workspace 2775 agent agent -"
    "z /home/agent/workspace 2775 agent agent -"
    (
      "A /home/agent/workspace - - - - "
      + "default:group:agent:rwx,default:user:moonburst:rwx,"
      + "group:agent:rwx,user:moonburst:rwx"
    )
    (
      "A /home/agent/models - - - - "
      + "default:group:agent:rwx,default:user:moonburst:rwx,"
      + "group:agent:rwx,user:moonburst:rwx"
    )
  ];

  security.sudo.extraRules = [
    {
      users = [ "moonburst" ];
      commands = [
        {
          command = "${agentWorker}/bin/agent-worker";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${agentPython}/bin/python3 ${agentWorker}/bin/agent-worker*";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # 3. 7900 XTX Inference Server (Locks strictly to GPU 0)
  systemd.user.services.llama-server = {
    after = [ "network.target" ];
    environment = {
      HSA_OVERRIDE_GFX_VERSION = "11.0.0";
      HIP_VISIBLE_DEVICES = "0";
    };
    serviceConfig = {
      ExecStart = "${startLlamaScript}";
      Restart = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    agent
    podman
    llamaGpu
    libnotify
    micro
    acl
  ];
}
