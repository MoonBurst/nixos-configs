// PodmanTwitchEngine.qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: twitchEngine

    property bool mainRunning: false
    property bool berryRunning: false
    property string mainWatching: ""
    property string berryWatching: ""
    property string mainClaim: ""
    property string berryClaim: ""
    property bool mainError: false
    property bool berryError: false

    property double lastMainRestart: 0
    property double lastBerryRestart: 0
    // Backoff cooldown: 5 minutes between auto-restarts to prevent spam
    readonly property double restartCooldown: 300000

    signal commandRequested(string cmd)

    Timer {
        interval: 15000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: twitchProc.running = true
    }

    Process {
        id: twitchProc
        command: [
            "python3", "-c",
            "import subprocess, json, re\n" +
            "def check_active(unit):\n" +
            "    try:\n" +
            "        return subprocess.check_output(['systemctl', 'is-active', unit], stderr=subprocess.DEVNULL).decode().strip() == 'active'\n" +
            "    except Exception: return False\n" +
            "def get_logs(unit):\n" +
            "    try:\n" +
            "        return subprocess.check_output(['journalctl', '-u', unit, '-n', '15', '--no-pager', '-o', 'cat'], stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore')\n" +
            "    except Exception: return ''\n" +
            "def parse_miner(logs):\n" +
            "    watching, claim, err = '', '', False\n" +
            "    tail8 = '\\n'.join(logs.splitlines()[-8:])\n" +
            "    idle = bool(re.search(r'Exiting|All drops claimed|No active campaigns|No channels available|Idle', tail8, re.I))\n" +
            "    for line in logs.splitlines():\n" +
            "        if 'Watching:' in line: watching = line.split()[-1]\n" +
            "        if 'Claimed drop:' in line: claim = line.split('Claimed drop:')[-1].strip()[:35]\n" +
            "    if idle: watching = ''\n" +
            "    tail5 = '\\n'.join(logs.splitlines()[-5:])\n" +
            "    err = bool(re.search(r'401 Unauthorized|403 Forbidden|rate limit|integrity check failed', tail5, re.I))\n" +
            "    return watching, claim, err\n" +
            "m_run = check_active('podman-twitch-miner.service')\n" +
            "b_run = check_active('podman-twitchminer-berrydrop.service')\n" +
            "m_watch, m_claim, m_err = parse_miner(get_logs('podman-twitch-miner.service')) if m_run else ('', '', False)\n" +
            "b_watch, b_claim, b_err = parse_miner(get_logs('podman-twitchminer-berrydrop.service')) if b_run else ('', '', False)\n" +
            "print(json.dumps({\n" +
            "    'main_running': m_run, 'berry_running': b_run,\n" +
            "    'main_watching': m_watch, 'berry_watching': b_watch,\n" +
            "    'main_claim': m_claim, 'berry_claim': b_claim,\n" +
            "    'main_err': m_err, 'berry_err': b_err\n" +
            "}))"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const obj = JSON.parse(data.trim())
                    twitchEngine.mainRunning = (obj.main_running === 1);
                    twitchEngine.berryRunning = (obj.berry_running === 1);
                    twitchEngine.mainWatching = obj.main_watching || "";
                    twitchEngine.berryWatching = obj.berry_watching || "";
                    twitchEngine.mainClaim = obj.main_claim || "";
                    twitchEngine.berryClaim = obj.berry_claim || "";
                    twitchEngine.mainError = (obj.main_err === 1);
                    twitchEngine.berryError = (obj.berry_err === 1);

                    let now = Date.now();
                    if (twitchEngine.mainError && (now - twitchEngine.lastMainRestart > twitchEngine.restartCooldown)) {
                        twitchEngine.lastMainRestart = now;
                        twitchEngine.commandRequested("sudo -n /run/current-system/sw/bin/podman restart twitch-miner");
                    }
                    if (twitchEngine.berryError && (now - twitchEngine.lastBerryRestart > twitchEngine.restartCooldown)) {
                        twitchEngine.lastBerryRestart = now;
                        twitchEngine.commandRequested("sudo -n /run/current-system/sw/bin/podman restart twitchminer-berrydrop");
                    }
                } catch (e) {}
            }
        }
    }
}
