import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: engine

    property string activeRevealedPath: ""
    signal revealReady(string path)

    function getDateStamp() {
        var d = new Date();
        var yyyy = d.getFullYear();
        var mm = String(d.getMonth() + 1).padStart(2, '0');
        var dd = String(d.getDate()).padStart(2, '0');
        return yyyy + "-" + mm + "-" + dd;
    }

    function embedAndDeliver(rawPath, rawNames, mode) {
        var baseDir = ShotState.saveDir();
        var histDir = ShotState.home() + "/.cache/quickshot_history";
        var ts = ShotState.timestamp();
        var dateStamp = getDateStamp();

        // Parse names and automatically append today's date to each recipient
        var names = rawNames.split(",").map(function(s) {
            var n = s.trim();
            if (n.length === 0) return "";
            return n.includes(dateStamp) ? n : (n + " " + dateStamp);
        }).filter(function(s) { return s.length > 0; });

        // Auto-Pruning: Keeps only the newest 50 screenshots in cache to prevent disk bloat
        var pruneScript = "ls -1t " + ShotState.shQuote(histDir) + "/*.png 2>/dev/null | tail -n +51 | while read -r old; do rm -f \"$old\" \"${old%.png}.json\"; done; ";
        var setupCmd = "mkdir -p " + ShotState.shQuote(baseDir) + " " + ShotState.shQuote(histDir) + "; " + pruneScript;

        if (names.length > 1) {
            var batchCmd = setupCmd;
            var firstOut = "";

            for (var i = 0; i < names.length; i++) {
                var target = names[i];
                var safeTarget = target.replace(/[^a-zA-Z0-9_\-]/g, "_");
                var outPath = baseDir + "/quickshot_" + ts + "_" + safeTarget + ".png";
                var histImg = histDir + "/quickshot_" + ts + "_" + safeTarget + ".png";
                var histMeta = histDir + "/quickshot_" + ts + "_" + safeTarget + ".json";
                if (i === 0) firstOut = outPath;

                batchCmd += "(magick " + ShotState.shQuote(rawPath) + " " +
                            "\\( -size 240x220 xc:none -fill 'rgba(100, 0, 255, 0.008)' " +
                            "-font 'Liberation-Sans-Bold' -pointsize 20 -gravity Center " +
                            "-annotate +0+0 " + ShotState.shQuote(target) + " " +
                            "-distort ScaleRotateTranslate 30 -write mpr:text +delete \\) " +
                            "\\( +clone -tile mpr:text -draw 'color 0,0 reset' \\) " +
                            "-compose Over -composite -define png:compression-level=1 " + ShotState.shQuote(outPath) + "; " +
                            "cp -f " + ShotState.shQuote(outPath) + " " + ShotState.shQuote(histImg) + "; " +
                            "echo '{\"name\":\"" + target + "\",\"path\":\"" + histImg + "\"}' > " + ShotState.shQuote(histMeta) + ") & ";
            }

            batchCmd += "wait; ";
            if (mode === "copy") {
                batchCmd += "wl-copy --type image/png < " + ShotState.shQuote(firstOut) + " && ";
            }
            batchCmd += "notify-send -a Quickshot 'Batch Watermarked (" + names.length + " copies)' " + ShotState.shQuote("Saved for: " + names.join(", "));

            Quickshell.execDetached(["sh", "-c", batchCmd]);
        } else if (names.length === 1) {
            var single = names[0];
            var safeSingle = single.replace(/[^a-zA-Z0-9_\-]/g, "_");
            var outPath = (mode === "save") ? (baseDir + "/quickshot_" + ts + "_" + safeSingle + ".png") : (baseDir + "/quickshot_" + ts + ".png");
            var histImg = histDir + "/quickshot_" + ts + "_" + safeSingle + ".png";
            var histMeta = histDir + "/quickshot_" + ts + "_" + safeSingle + ".json";

            var cmd = setupCmd +
                      "magick " + ShotState.shQuote(rawPath) + " " +
                      "\\( -size 240x220 xc:none -fill 'rgba(100, 0, 255, 0.008)' " +
                      "-font 'Liberation-Sans-Bold' -pointsize 20 -gravity Center " +
                      "-annotate +0+0 " + ShotState.shQuote(single) + " " +
                      "-distort ScaleRotateTranslate 30 -write mpr:text +delete \\) " +
                      "\\( +clone -tile mpr:text -draw 'color 0,0 reset' \\) " +
                      "-compose Over -composite -define png:compression-level=1 " + ShotState.shQuote(rawPath) + "; " +
                      "cp -f " + ShotState.shQuote(rawPath) + " " + ShotState.shQuote(histImg) + "; " +
                      "echo '{\"name\":\"" + single + "\",\"path\":\"" + histImg + "\"}' > " + ShotState.shQuote(histMeta) + "; ";

            if (mode === "copy") {
                cmd += "wl-copy --type image/png < " + ShotState.shQuote(rawPath) + " && notify-send -a Quickshot 'Copied to clipboard' 'Watermark: " + single + "'";
            } else {
                cmd += "cp -f " + ShotState.shQuote(rawPath) + " " + ShotState.shQuote(outPath) + " && notify-send -a Quickshot 'Screenshot saved' " + ShotState.shQuote(outPath);
            }

            Quickshell.execDetached(["sh", "-c", cmd]);
        } else {
            // Clean un-watermarked screenshot
            var cleanPath = (mode === "save") ? (baseDir + "/quickshot_" + ts + ".png") : rawPath;
            var cleanHistImg = histDir + "/quickshot_" + ts + "_clean.png";
            var cleanHistMeta = histDir + "/quickshot_" + ts + "_clean.json";

            var cleanCmd = setupCmd +
                           "cp -f " + ShotState.shQuote(rawPath) + " " + ShotState.shQuote(cleanHistImg) + "; " +
                           "echo '{\"name\":\"Screenshot\",\"path\":\"" + cleanHistImg + "\"}' > " + ShotState.shQuote(cleanHistMeta) + "; ";

            if (mode === "copy") {
                cleanCmd += "wl-copy --type image/png < " + ShotState.shQuote(rawPath) + " && notify-send -a Quickshot 'Copied to clipboard' " + ShotState.shQuote(rawPath);
            } else {
                cleanCmd += "cp -f " + ShotState.shQuote(rawPath) + " " + ShotState.shQuote(cleanPath) + " && notify-send -a Quickshot 'Screenshot saved' " + ShotState.shQuote(cleanPath);
            }
            Quickshell.execDetached(["sh", "-c", cleanCmd]);
        }
    }

    // High-Pass Revealer + Automated Optical Leaker OCR
    Process {
        id: revealProc
        property string targetFile: ""
        onExited: {
            engine.activeRevealedPath = targetFile;
            engine.revealReady(targetFile);

            var ocrCmd = [
                "sh", "-c",
                "if command -v tesseract >/dev/null 2>&1; then " +
                "  unrot='/tmp/test_fingerprints/UNROTATED.png'; " +
                "  magick " + ShotState.shQuote(targetFile) + " -distort ScaleRotateTranslate -30 \"$unrot\"; " +
                "  leaker=$(tesseract \"$unrot\" stdout --psm 6 2>/dev/null | grep -E -o '[a-zA-Z0-9_\-]{3,}' | head -n 2 | paste -sd ' ' -); " +
                "  rm -f \"$unrot\"; " +
                "  if [ -n \"$leaker\" ]; then " +
                "    printf \"%s\" \"$leaker\" | wl-copy; " +
                "    notify-send -a Quickshot -u critical '🚨 LEAK IDENTIFIED' \"Leaker: $leaker (Copied to clipboard)\"; " +
                "  fi; " +
                "fi"
            ];
            Quickshell.execDetached(ocrCmd);
        }
    }

    function executeReveal(cropPath) {
        var ts = new Date().getTime();
        var outPath = "/tmp/test_fingerprints/REVEALED_" + ts + ".png";
        revealProc.targetFile = outPath;
        revealProc.command = [
            "sh", "-c",
            "mkdir -p /tmp/test_fingerprints; " +
            "magick " + ShotState.shQuote(cropPath) + " -channel B -separate \\( +clone -blur 0x2 \\) -compose Subtract -composite -auto-level -define png:compression-level=1 " + ShotState.shQuote(outPath) + "; " +
            "rm -f " + ShotState.shQuote(cropPath)
        ];
        revealProc.running = true;
    }

    function saveRevealedProof(path, mode) {
        var baseDir = ShotState.saveDir();
        var histDir = ShotState.home() + "/.cache/quickshot_history";
        var ts = ShotState.timestamp();
        var proofPath = baseDir + "/quickshot_" + ts + "_REVEALED.png";
        var histImg = histDir + "/quickshot_" + ts + "_REVEALED.png";
        var histMeta = histDir + "/quickshot_" + ts + "_REVEALED.json";

        var cmd = "mkdir -p " + ShotState.shQuote(baseDir) + " " + ShotState.shQuote(histDir) + "; " +
                  "cp -f " + ShotState.shQuote(engine.activeRevealedPath) + " " + ShotState.shQuote(proofPath) + "; " +
                  "cp -f " + ShotState.shQuote(proofPath) + " " + ShotState.shQuote(histImg) + "; " +
                  "echo '{\"name\":\"REVEALED PROOF\",\"path\":\"" + histImg + "\"}' > " + ShotState.shQuote(histMeta) + "; ";

        var action = (mode === "copy")
            ? ("wl-copy --type image/png < " + ShotState.shQuote(proofPath) + " && notify-send -a Quickshot 'Revealed Proof Copied' 'Stored as [Image: REVEALED PROOF]'; ")
            : ("notify-send -a Quickshot 'Revealed Proof Saved' " + ShotState.shQuote(proofPath) + "; ");

        Quickshell.execDetached(["sh", "-c", cmd + action]);
    }
}
