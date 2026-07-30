{ config, pkgs, lib, inputs, ... }:

let
  # ============================================================================
  # HARDWARE
  # ============================================================================
  gpuChoice = "7900";

  readspeed = "+20%";

  pthModelPath = "/home/moonburst/Documents/voice_files/Sage_e300_s25200.pth";

  piperNative = pkgs.stdenv.mkDerivation rec {
    pname = "piper-tts-native";
    version = "2023.11.14-2";

    src = pkgs.fetchurl {
      url = "https://github.com/rhasspy/piper/releases/download/${version}/piper_linux_x86_64.tar.gz";
      sha256 = "sha256-pQy0XzVbevH211jBs2BxeHe6CjmMyMvm0qejom4iWZI=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/piper-native $out/bin
      cp -r . $out/share/piper-native/
      chmod +x $out/share/piper-native/piper
      ln -s $out/share/piper-native/piper $out/bin/piper
      runHook postInstall
    '';

    meta = {
      description = "Piper neural TTS — native C++ binary release (MIT, 2023.11.14-2)";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };

  pythonPkgs = pkgs.python3Packages;


  fairseqPkg = pythonPkgs.buildPythonPackage {
    pname = "fairseq";
    version = "unstable-2026-07-26";

    format = "other";

    # facebookresearch/fairseq is itself archived/read-only (like rhasspy/piper),
    # so this pin should never go stale. main's HEAD stopped moving for good.
    src = pkgs.fetchFromGitHub {
      owner = "facebookresearch";
      repo = "fairseq";
      rev = "3d262bb";
      hash = "sha256-g1ArKtmHA7YiIqKwrMDpGp4dc47tFvy6uS/zwfenFB0=";
    };

    postPatch = ''
      # Python 3.13 compat: dataclasses._get_field rejects mutable defaults
      # more strictly than when fairseq was written. Same patch that was
      # previously applied at runtime via sed in sage-setup-script, now
      # baked into the build instead.
      sed -i '1s/^/import dataclasses\n_orig_get_field = dataclasses._get_field\ndef _patched_get_field(cls, name, type, kw_only):\n    try:\n        return _orig_get_field(cls, name, type, kw_only)\n    except ValueError as e:\n        if "mutable default" in str(e):\n            val = getattr(cls, name, dataclasses.MISSING)\n            f = dataclasses.field(default=val, kw_only=kw_only)\n            f.name = name\n            return f\n        raise e\ndataclasses._get_field = _patched_get_field\n/' fairseq/__init__.py
    '';

    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/${pkgs.python3.sitePackages}
      cp -r fairseq $out/${pkgs.python3.sitePackages}/
      runHook postInstall
    '';

    doCheck = false;
    meta.description = "Sequence modeling toolkit (source-only, matches the proven-working setup) — RVC's HuBERT feature extractor depends on this";
  };

  praatParselmouthPkg = pythonPkgs.buildPythonPackage rec {
    pname = "praat-parselmouth";
    version = "0.4.7";
    format = "wheel";
    src = pythonPkgs.fetchPypi {
      pname = "praat_parselmouth";
      inherit version format;
      dist = "cp313";
      python = "cp313";
      abi = "cp313";
      platform = "manylinux2014_x86_64.manylinux_2_17_x86_64";
      hash = "sha256-wi2fgJhOkRYuO+ExCWN/Xf4Q0spNOxXt1+eCVQumJ/E=";
    };


    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    propagatedBuildInputs = [ pythonPkgs.numpy ];
    doCheck = false;
    pythonImportsCheck = [ "parselmouth" ];
    meta.description = "Praat bindings used by rvc_python for pitch/formant analysis";
  };

  rvcPythonPkg = pythonPkgs.buildPythonPackage rec {
    pname = "rvc-python";
    version = "0.1.5";
    format = "wheel";
    src = pythonPkgs.fetchPypi {
      pname = "rvc_python";
      inherit version format;
      dist = "py3";
      python = "py3";
      abi = "none";
      platform = "any";
      hash = "sha256-0t/X4g4yBilSOCsIRpefXN5fMZJm3uBZkTY0n1tSGrA=";
    };
    propagatedBuildInputs = [ fairseqPkg praatParselmouthPkg ] ++ (with pythonPkgs; [
      torchcrepe
      faiss ffmpeg-python omegaconf pyworld librosa soundfile scipy resampy tqdm
    ]);
    dontBuild = true;
    doCheck = false;
    dontCheckRuntimeDeps = true;
    pythonImportsCheck = [ ];
    meta.description = "RVC voice conversion library, wraps HuBERT + the RVC generator network";
  };

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    soundfile
    librosa
    scipy
    faiss
    ffmpeg-python
    omegaconf
    pyworld
    loguru
    sacrebleu
    bitarray
    hydra-core
    av
    resampy
    tqdm
    torchcrepe
  ] ++ [ rvcPythonPkg fairseqPkg praatParselmouthPkg ]);

  # GPU Environment selection for AMD RX 7900 XT (RDNA3 / gfx1100)
  gpuEnvVars = if gpuChoice == "7900" then ''
    export MESA_VK_DEVICE_SELECT="1002:744c!"
    export DRI_PRIME="pci-0000:28:00.0"
    export HIP_VISIBLE_DEVICES=0
    export CUDA_VISIBLE_DEVICES=0
    export HSA_OVERRIDE_GFX_VERSION=11.0.0
    export PYTORCH_ROCM_ARCH=gfx1100
    export HIPBLASLT_ENABLE=0

    # Disable MIOpen solver to force direct rocBLAS GPU execution
    export MIOPEN_DISABLE_CACHE=1
    export MIOPEN_FIND_MODE=NONE
    export MIOPEN_DEBUG_CONV_GEMM=0
  '' else if gpuChoice == "6400" then ''
    export MESA_VK_DEVICE_SELECT="1002:743f!"
    export DRI_PRIME="pci-0000:2b:00.0"
    export HIP_VISIBLE_DEVICES=0
    export HSA_OVERRIDE_GFX_VERSION=10.3.0
    export HIPBLASLT_ENABLE=0
  '' else "";

  rawSageDaemon = pkgs.writers.writePython3Bin "raw-sage-daemon" {
    libraries = [ ];
    flakeIgnore = [ "E501" "E302" "E305" "F401" "E226" "F841" "E261" "E402" ];
  } ''
    import sys
    import os

    sys.path.insert(0, "/home/moonburst/.local/share/sage-tts/libs")

    import time
    import glob
    import shutil
    import tempfile
    import subprocess
    import socket
    import torch
    from rvc_python.infer import RVCInference

    PTH_PATH = os.path.expandvars(os.path.expanduser("${pthModelPath}"))
    SOCKET_PATH = "/tmp/sage_tts.sock"
    PIPER_MODEL = os.path.expandvars(os.path.expanduser("~/.local/share/sage-tts/piper/en_US-amy-medium.onnx"))
    READSPEED = "${readspeed}"

    # Resident piper process state (avoids reloading the ONNX model on every call)
    _piper_proc = None
    _piper_out_dir = None

    def cleanup_stale_piper_dirs():
        """Remove leftover /tmp/sage_piper_* dirs from previous daemon runs
        (crashes, restarts) so they don't accumulate indefinitely."""
        for d in glob.glob("/tmp/sage_piper_*"):
            if d == _piper_out_dir:
                continue
            try:
                shutil.rmtree(d)
            except Exception:
                pass

    def get_atempo_filter(speed_str):
        try:
            clean = speed_str.strip().replace("%", "")
            val = float(clean)
            mult = 1.0 + (val / 100.0)
            return f"atempo={mult:.2f}"
        except Exception:
            return "atempo=1.0"

    def ensure_piper_model():
        if not os.path.exists(PIPER_MODEL):
            os.makedirs(os.path.dirname(PIPER_MODEL), exist_ok=True)
            print("Downloading fast local Piper voice model...", flush=True)
            subprocess.run([
                "curl", "-s", "-L",
                "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx",
                "-o", PIPER_MODEL
            ], check=True)
            subprocess.run([
                "curl", "-s", "-L",
                "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx.json",
                "-o", PIPER_MODEL + ".json"
            ], check=True)

    def start_piper_process():
        """Launch piper once and keep it resident, fed one line of text per request
        via stdin. This avoids the ~1.4s process-spawn + model-load cost that a
        fresh `piper` invocation pays every single time."""
        global _piper_proc, _piper_out_dir
        ensure_piper_model()
        cleanup_stale_piper_dirs()
        _piper_out_dir = tempfile.mkdtemp(prefix="sage_piper_")

        _piper_proc = subprocess.Popen(
            ["piper", "--model", PIPER_MODEL, "--output_dir", _piper_out_dir],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=None,  # inherit daemon's stderr so real errors hit journalctl instead of vanishing
            bufsize=1,
        )
        print("Resident Piper process started (model loaded once, reused per call).", flush=True)

    def restart_piper_process():
        try:
            if _piper_proc is not None:
                _piper_proc.kill()
                _piper_proc.wait(timeout=5)
        except Exception:
            pass
        start_piper_process()

    def piper_synthesize(text, timeout=10.0):
        """Send text to the resident piper process and wait for its output wav
        to appear in the output dir. Sequential single-connection server, so
        file-arrival order matches request order."""
        if _piper_proc is None or _piper_proc.poll() is not None:
            restart_piper_process()

        before = set(glob.glob(os.path.join(_piper_out_dir, "*.wav")))

        try:
            _piper_proc.stdin.write((text + "\n").encode("utf-8"))
            _piper_proc.stdin.flush()
        except (BrokenPipeError, OSError):
            restart_piper_process()
            _piper_proc.stdin.write((text + "\n").encode("utf-8"))
            _piper_proc.stdin.flush()

        deadline = time.time() + timeout
        new_file = None
        while time.time() < deadline:
            after = set(glob.glob(os.path.join(_piper_out_dir, "*.wav")))
            diff = after - before
            if diff:
                new_file = sorted(diff)[0]
                break
            time.sleep(0.01)

        if new_file:
            # Guard against reading the file while piper is still writing/closing it:
            # wait until its size stops changing before handing it off.
            last_size = -1
            stable_checks = 0
            stability_deadline = time.time() + 2.0
            while time.time() < stability_deadline:
                try:
                    size = os.path.getsize(new_file)
                except OSError:
                    size = -1
                if size == last_size and size > 0:
                    stable_checks += 1
                    if stable_checks >= 2:
                        break
                else:
                    stable_checks = 0
                last_size = size
                time.sleep(0.02)
        else:
            print(f"[Piper Warning] timed out waiting for output wav (text: {text[:60]!r})", flush=True)

        return new_file

    def generate_base_speech(text, output_wav):
        if not text or not text.strip():
            return False
        clean_text = text.strip()
        if not clean_text.endswith((".", "!", "?")):
            clean_text += "."

        atempo = get_atempo_filter(READSPEED)

        raw_wav = piper_synthesize(clean_text)
        if not raw_wav or not os.path.exists(raw_wav):
            return False

        try:
            ff = subprocess.run(
                ["ffmpeg", "-y", "-i", raw_wav, "-filter:a", atempo, "-ar", "16000", "-ac", "1", output_wav],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
            if ff.returncode != 0:
                print(f"[Piper Warning] ffmpeg failed (rc={ff.returncode}): {ff.stdout.decode(errors='replace')[-500:]}", flush=True)
        finally:
            try:
                os.remove(raw_wav)
            except Exception:
                pass

        return os.path.exists(output_wav) and os.path.getsize(output_wav) > 100

    def optimize_rvc_settings(rvc_instance, device):
        torch.backends.cudnn.enabled = False
        torch.backends.cudnn.benchmark = False
        torch.backends.cudnn.deterministic = True

        rvc_instance.f0method = "pm"
        rvc_instance.index_rate = 0.0
        rvc_instance.resample_sr = 0
        if hasattr(rvc_instance, "vc") and rvc_instance.vc:
            rvc_instance.vc.f0_method = "pm"
            rvc_instance.vc.resample_sr = 0
            rvc_instance.vc.device = device
        if hasattr(rvc_instance, "models"):
            for m in rvc_instance.models.values():
                m["index"] = ""

    def main():
        if not os.path.exists(PTH_PATH):
            print(f"[Sage Daemon Error] Model file not found at {PTH_PATH}", file=sys.stderr, flush=True)
            return

        if os.path.exists(SOCKET_PATH):
            try:
                os.remove(SOCKET_PATH)
            except Exception:
                pass

        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(SOCKET_PATH)
        server.listen(5)

        device = "cuda:0" if torch.cuda.is_available() else "cpu"
        print(f"Loading Sage Model onto RX 7900 GPU VRAM | Speed: {READSPEED} | ROCm Status: {torch.cuda.is_available()} | Device: {device}", flush=True)

        start_piper_process()

        rvc = RVCInference(device=device)
        rvc.load_model(PTH_PATH)
        optimize_rvc_settings(rvc, device)

        print("Pre-warming HuBERT and audio pipelines in RX 7900 GPU VRAM...", flush=True)
        with tempfile.TemporaryDirectory() as tmpdir:
            w_base = os.path.join(tmpdir, "w_base.wav")
            w_out = os.path.join(tmpdir, "w_out.wav")
            try:
                if generate_base_speech("System ready.", w_base):
                    optimize_rvc_settings(rvc, device)
                    with torch.inference_mode():
                        rvc.infer_file(w_base, w_out)
            except Exception as e:
                print(f"[Warmup Note] {e}", file=sys.stderr, flush=True)

        print("Sage Voice Model pre-loaded in RX 7900 GPU VRAM! Ready for notifications!", flush=True)

        while True:
            try:
                conn, _ = server.accept()
                data = conn.recv(4096).decode("utf-8").strip()
                conn.close()

                if not data:
                    continue

                with tempfile.TemporaryDirectory() as tmpdir:
                    base_tts_path = os.path.join(tmpdir, "base.wav")
                    sage_audio_path = os.path.join(tmpdir, "sage_output.wav")

                    t0 = time.time()
                    if not generate_base_speech(data, base_tts_path):
                        continue
                    t1 = time.time()

                    optimize_rvc_settings(rvc, device)
                    with torch.inference_mode():
                        rvc.infer_file(base_tts_path, sage_audio_path)
                    t2 = time.time()

                    print(f"[INSTANT VOICE TIMING] Base Speech (piper): {t1 - t0:.3f}s | Sage RX 7900 VRAM RVC: {t2 - t1:.3f}s | Total: {t2 - t0:.3f}s", flush=True)

                    if os.path.exists(sage_audio_path) and os.path.getsize(sage_audio_path) > 0:
                        subprocess.run(["pw-play", sage_audio_path], check=False)
            except Exception as e:
                print(f"[Sage Daemon Error] {e}", file=sys.stderr, flush=True)

    if __name__ == "__main__":
        main()
  '';

  sage-daemon = pkgs.writeShellScriptBin "sage-daemon" ''
    ${gpuEnvVars}

    export PYTHONUNBUFFERED=1
    export PATH="${piperNative}/bin:${pkgs.curl}/bin:${pkgs.pipewire}/bin:${pkgs.ffmpeg}/bin:$PATH"
    export LD_LIBRARY_PATH="${pkgs.zstd.out}/lib:${pkgs.numactl}/lib:/run/opengl-driver/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:$LD_LIBRARY_PATH"

    exec ${pythonEnv}/bin/python3 ${rawSageDaemon}/bin/raw-sage-daemon "$@"
  '';

  sage-client = pkgs.writeShellScriptBin "sage-tts" ''
    ${pkgs.python3}/bin/python3 -c '
import socket, sys
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect("/tmp/sage_tts.sock")
    s.sendall(" ".join(sys.argv[1:]).encode("utf-8"))
    s.close()
except Exception as e:
    print("Sage daemon not running!", file=sys.stderr)
' "$@"
  '';

  sage-tts-suite = pkgs.symlinkJoin {
    name = "sage-tts-suite";
    paths = [ sage-daemon sage-client ];
  };
in
{
  environment.systemPackages = [ sage-tts-suite ];

  systemd.user.services.sage-daemon = {
    description = "Sage AI Voice TTS Daemon";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${sage-daemon}/bin/sage-daemon";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
