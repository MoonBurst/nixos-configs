import QtQuick
import Quickshell.Io

Process {
    id: escWatcherProcess

    property bool active: false
    signal escapePressed()

    running: active
    command: [
        "python3", "-u", "-c",
        "import glob, struct, select, sys\n" +
        "fds = []\n" +
        "for dev in glob.glob('/dev/input/by-id/*-event-kbd') + glob.glob('/dev/input/event*'):\n" +
        "    try:\n" +
        "        fds.append(open(dev, 'rb', buffering=0))\n" +
        "    except Exception:\n" +
        "        pass\n" +
        "if not fds:\n" +
        "    sys.exit(0)\n" +
        "fmt = 'llHHi' if struct.calcsize('l') == 8 else 'iiHHi'\n" +
        "sz = struct.calcsize(fmt)\n" +
        "while True:\n" +
        "    r, _, _ = select.select(fds, [], [])\n" +
        "    for fd in r:\n" +
        "        try:\n" +
        "            d = fd.read(sz)\n" +
        "            if len(d) == sz:\n" +
        "                _, _, t, code, val = struct.unpack(fmt, d)\n" +
        "                if t == 1 and code == 1 and val == 1:\n" +
        "                    print('ESC', flush=True)\n" +
        "        except Exception:\n" +
        "            pass\n"
    ]
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: data => {
            if (data.trim() === "ESC") escWatcherProcess.escapePressed();
        }
    }
}
