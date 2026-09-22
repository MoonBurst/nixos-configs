import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: engine

    property string activeRevealedPath: ""
    signal revealReady(string path)

    function embedAndDeliver(rawPath, rawNames, mode) {
        var baseDir = ShotState.saveDir();
        var histDir = ShotState.home() + "/.cache/quickshot_history";
        var ts = ShotState.timestamp();
        var names = rawNames.split(",").map(s => s.trim()).filter(s => s.length > 0);
        var setupCmd = "mkdir -p " + ShotState.shQuote(baseDir) + " " + ShotState.shQuote(histDir) + "; ";

        if (names.length > 1) {
            // Parallel batch pipeline: generate all recipient images and permanent JSON metadata
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
            // Single recipient
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
            var histImg = histDir + "/quickshot_" + ts + "_clean.png";
            var histMeta = histDir + "/quickshot_" + ts + "_clean.json";

            var cleanCmd = setupCmd +
                           "cp -f " + ShotState.shQuote(rawPath) + " " + ShotState.shQuote(histImg) + "; " +
                           "echo '{\"name\":\"Screenshot\",\"path\":\"" + histImg + "\"}' > " + ShotState.shQuote(histMeta) + "; ";

            if (mode === "copy") {
                cleanCmd += "wl-copy --type image/png < " + ShotState.shQuote(rawPath) + " && notify-send -a Quickshot 'Copied to clipboard' " + ShotState.shQuote(rawPath);
            } else {
                cleanCmd += "cp -f " + ShotState.shQuote(rawPath) + " " + ShotState.shQuote(cleanPath) + " && notify-send -a Quickshot 'Screenshot saved' " + ShotState.shQuote(cleanPath);
            }
            Quickshell.execDetached(["sh", "-c", cleanCmd]);
        }
    }

    Process {
        id: revealProc
        property string targetFile: ""
        onExited: {
            engine.activeRevealedPath = targetFile;
            engine.revealReady(targetFile);
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
