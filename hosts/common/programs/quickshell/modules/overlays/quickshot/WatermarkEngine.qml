import Quickshell.Io
import Quickshell
import QtQuick

// Dedicated, headless backend engine for parallelized watermarking,
// high-pass leak extraction, and clipboard history tagging.
Item {
    id: engine

    property string activeRevealedPath: ""
    signal revealReady(string path)

    // Parallel multi-core batch embedder
    function embedAndDeliver(rawPath, rawNames, mode) {
        var baseDir = ShotState.saveDir();
        var ts = ShotState.timestamp();
        var names = rawNames.split(",").map(s => s.trim()).filter(s => s.length > 0);

        if (names.length > 1) {
            // Parallel batch pipeline: generate all recipient images simultaneously across CPU cores
            var script = "mkdir -p " + ShotState.shQuote(baseDir) + "; mkdir -p /tmp/clipboard_thumbnails; ";
            var firstOut = baseDir + "/quickshot_" + ts + "_" + names[0].replace(/[^a-zA-Z0-9_\-]/g, "_") + ".png";

            for (var i = 0; i < names.length; i++) {
                var target = names[i];
                var safeTarget = target.replace(/[^a-zA-Z0-9_\-]/g, "_");
                var outPath = baseDir + "/quickshot_" + ts + "_" + safeTarget + ".png";

                script += "(magick " + ShotState.shQuote(rawPath) + " " +
                          "\\( -size 240x220 xc:none -fill 'rgba(100, 0, 255, 0.008)' " +
                          "-font 'Liberation-Sans-Bold' -pointsize 20 -gravity Center " +
                          "-annotate +0+0 " + ShotState.shQuote(target) + " " +
                          "-distort ScaleRotateTranslate 30 -write mpr:text +delete \\) " +
                          "\\( +clone -tile mpr:text -draw 'color 0,0 reset' \\) " +
                          "-compose Over -composite -define png:compression-level=1 " + ShotState.shQuote(outPath) + "; " +
                          "cliphist store < " + ShotState.shQuote(outPath) + "; " +
                          "cid=$(cliphist list | head -n 1 | cut -f1); " +
                          "chash=$(md5sum " + ShotState.shQuote(outPath) + " | cut -d' ' -f1); " +
                          "echo " + ShotState.shQuote(target) + " > /tmp/clipboard_thumbnails/quickshell_clip_label_${cid}.txt; " +
                          "echo " + ShotState.shQuote(target) + " > /tmp/clipboard_thumbnails/label_${chash}.txt) & ";
            }

            // Clipboard priority: wait for first image, copy immediately, then let the rest finish in background
            script += "wait; ";
            if (mode === "copy") {
                script += "wl-copy --type image/png < " + ShotState.shQuote(firstOut) + " && " +
                          "firstHash=$(md5sum " + ShotState.shQuote(firstOut) + " | cut -d' ' -f1); " +
                          "topId=$(cliphist list | head -n 1 | cut -f1); " +
                          "echo " + ShotState.shQuote(names[0]) + " > /tmp/clipboard_thumbnails/quickshell_clip_label_${topId}.txt; " +
                          "echo " + ShotState.shQuote(names[0]) + " > /tmp/clipboard_thumbnails/label_${firstHash}.txt; ";
            }
            script += "notify-send -a Quickshot 'Batch Watermarked (" + names.length + " copies)' " + ShotState.shQuote("Saved for: " + names.join(", "));

            Quickshell.execDetached(["sh", "-c", script]);
        } else if (names.length === 1) {
            // Single recipient fast embed
            var single = names[0];
            var cmd = "mkdir -p /tmp/clipboard_thumbnails; " +
                      "magick " + ShotState.shQuote(rawPath) + " " +
                      "\\( -size 240x220 xc:none -fill 'rgba(100, 0, 255, 0.008)' " +
                      "-font 'Liberation-Sans-Bold' -pointsize 20 -gravity Center " +
                      "-annotate +0+0 " + ShotState.shQuote(single) + " " +
                      "-distort ScaleRotateTranslate 30 -write mpr:text +delete \\) " +
                      "\\( +clone -tile mpr:text -draw 'color 0,0 reset' \\) " +
                      "-compose Over -composite -define png:compression-level=1 " + ShotState.shQuote(rawPath) + "; " +
                      "cliphist store < " + ShotState.shQuote(rawPath) + "; " +
                      "cid=$(cliphist list | head -n 1 | cut -f1); " +
                      "chash=$(md5sum " + ShotState.shQuote(rawPath) + " | cut -d' ' -f1); " +
                      "echo " + ShotState.shQuote(single) + " > /tmp/clipboard_thumbnails/quickshell_clip_label_${cid}.txt; " +
                      "echo " + ShotState.shQuote(single) + " > /tmp/clipboard_thumbnails/label_${chash}.txt; ";

            var copy = (mode === "copy")
                ? ("wl-copy --type image/png < " + ShotState.shQuote(rawPath) + " && notify-send -a Quickshot 'Copied to clipboard' 'Watermark: " + single + "'")
                : ("notify-send -a Quickshot 'Screenshot saved' " + ShotState.shQuote(rawPath));

            Quickshell.execDetached(["sh", "-c", cmd + copy]);
        } else {
            // Clean un-watermarked screenshot
            var clean = (mode === "copy")
                ? ("wl-copy --type image/png < " + ShotState.shQuote(rawPath) + " && notify-send -a Quickshot 'Copied to clipboard' " + ShotState.shQuote(rawPath))
                : ("notify-send -a Quickshot 'Screenshot saved' " + ShotState.shQuote(rawPath));
            Quickshell.execDetached(["sh", "-c", clean]);
        }
    }

    // High-speed RAM-disk high-pass revealer
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
        var ts = ShotState.timestamp();
        var proofPath = baseDir + "/quickshot_" + ts + "_REVEALED.png";
        var cmd = "mkdir -p " + ShotState.shQuote(baseDir) + "; mkdir -p /tmp/clipboard_thumbnails; " +
                  "cp -f " + ShotState.shQuote(engine.activeRevealedPath) + " " + ShotState.shQuote(proofPath) + "; " +
                  "cliphist store < " + ShotState.shQuote(proofPath) + "; " +
                  "cid=$(cliphist list | head -n 1 | cut -f1); " +
                  "chash=$(md5sum " + ShotState.shQuote(proofPath) + " | cut -d' ' -f1); " +
                  "echo 'REVEALED' > /tmp/clipboard_thumbnails/quickshell_clip_label_${cid}.txt; " +
                  "echo 'REVEALED' > /tmp/clipboard_thumbnails/label_${chash}.txt; ";

        var copy = (mode === "copy")
            ? ("wl-copy --type image/png < " + ShotState.shQuote(proofPath) + " && notify-send -a Quickshot 'Revealed Proof Copied' 'Stored in clipboard as [Image: REVEALED]'; ")
            : ("notify-send -a Quickshot 'Revealed Proof Saved' " + ShotState.shQuote(proofPath) + "; ");

        Quickshell.execDetached(["sh", "-c", cmd + copy]);
    }
}
