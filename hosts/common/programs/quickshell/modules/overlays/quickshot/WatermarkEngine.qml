import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: engine

    property string activeRevealedPath: ""
    signal revealReady(string path)

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    function getDateStamp() {
        var d = new Date();
        var yyyy = d.getFullYear();
        var mm = String(d.getMonth() + 1).padStart(2, '0');
        var dd = String(d.getDate()).padStart(2, '0');
        return yyyy + "-" + mm + "-" + dd;
    }

    // Helper to generate the uniform ImageMagick command chain
    function buildMagickSubCommand(src, dest, watermarkText) {
        return "magick " + ShotState.shQuote(src) + " " +
        "\\( -size 240x220 xc:none -fill 'rgba(100, 0, 255, 0.008)' " +
        "-font 'Liberation-Sans-Bold' -pointsize 20 -gravity Center " +
        "-annotate +0+0 " + ShotState.shQuote(watermarkText) + " " +
        "-distort ScaleRotateTranslate 30 -write mpr:text +delete \\) " +
        "\\( +clone -tile mpr:text -draw 'color 0,0 reset' \\) " +
        "-compose Over -composite -define png:compression-level=1 " + ShotState.shQuote(dest);
    }

    // Helper to generate escaped JSON strings safely
    function buildJsonEcho(name, path, destMetaFile) {
        var obj = { "name": name, "path": path };
        return "echo " + ShotState.shQuote(JSON.stringify(obj)) + " > " + ShotState.shQuote(destMetaFile);
    }

    function embedAndDeliver(rawPath, rawNames, mode) {
        var baseDir = ShotState.saveDir();
        var histDir = ShotState.home() + "/.cache/quickshot_history";
        var ts = ShotState.timestamp();
        var dateStamp = getDateStamp();

        var names = rawNames.split(",").map(function(s) {
            var n = s.trim();
            if (n.length === 0) return "";
            return n.includes(dateStamp) ? n : (n + " " + dateStamp);
        }).filter(function(s) { return s.length > 0; });

        var pruneScript = "ls -1t " + ShotState.shQuote(histDir) + "/*.png 2>/dev/null | tail -n +51 | while read -r old; do rm -f \"$old\" \"${old%.png}.json\"; done; ";
        var batchCmd = "mkdir -p " + ShotState.shQuote(baseDir) + " " + ShotState.shQuote(histDir) + "; " + pruneScript;

        if (names.length > 0) {
            var firstOut = "";

            for (var i = 0; i < names.length; i++) {
                var target = names[i];
                var safeTarget = target.replace(/[^a-zA-Z0-9_\-]/g, "_");

                // If saving a single file, customize the name target. Otherwise use standard batch paths.
                var outPath = (names.length === 1 && mode !== "save") ? (baseDir + "/quickshot_" + ts + ".png") : (baseDir + "/quickshot_" + ts + "_" + safeTarget + ".png");
                var histImg = histDir + "/quickshot_" + ts + "_" + safeTarget + ".png";
                var histMeta = histDir + "/quickshot_" + ts + "_" + safeTarget + ".json";

                if (i === 0) firstOut = outPath;

                // Run sequentially to protect system resources, or add an '&' before the semicolon if backgrounding is required
                batchCmd += "(" + buildMagickSubCommand(rawPath, outPath, target) + "; " +
                "cp -f " + ShotState.shQuote(outPath) + " " + ShotState.shQuote(histImg) + "; " +
                buildJsonEcho(safeTarget, histImg, histMeta) + "); ";
            }

            if (mode === "copy") {
                batchCmd += "wl-copy --type image/png < " + ShotState.shQuote(firstOut) + " && ";
                batchCmd += "notify-send -a Quickshot 'Copied to clipboard' 'Watermark active'; ";
            } else {
                batchCmd += "notify-send -a Quickshot 'Screenshot Saved' " + ShotState.shQuote("Count: " + names.length);
            }

            Quickshell.execDetached(["sh", "-c", batchCmd]);
        } else {
            // Clean path fallback (No watermarks requested)
            var cleanPath = (mode === "save") ? (baseDir + "/quickshot_" + ts + ".png") : rawPath;
            var cleanHistImg = histDir + "/quickshot_" + ts + "_clean.png";
            var cleanHistMeta = histDir + "/quickshot_" + ts + "_clean.json";

            var cleanCmd = batchCmd +
            "cp -f " + ShotState.shQuote(rawPath) + " " + ShotState.shQuote(cleanHistImg) + "; " +
            buildJsonEcho("Screenshot", cleanHistImg, cleanHistMeta) + "; ";

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

            var unrotPath = engine.runtimeDir + "/test_fingerprints/UNROTATED.png";
            var ocrCmd = [
                "sh", "-c",
                'if command -v tesseract >/dev/null 2>&1; then ' +
                '  unrot="$1"; ' +
                '  magick "$2" -distort ScaleRotateTranslate -30 "$unrot"; ' +
                '  leaker=$(tesseract "$unrot" stdout --psm 6 2>/dev/null | grep -E -o "[a-zA-Z0-9_-]{3,}" | head -n 2 | paste -sd " " -); ' +
                '  rm -f "$unrot"; ' +
                '  if [ -n "$leaker" ]; then ' +
                '    printf "%s" "$leaker" | wl-copy; ' +
                '    notify-send -a Quickshot -u critical "🚨 LEAK IDENTIFIED" "Leaker: $leaker (Copied to clipboard)"; ' +
                '  fi; ' +
                'fi',
                "sh", unrotPath, targetFile
            ];
            Quickshell.execDetached(ocrCmd);
        }
    }

    function executeReveal(cropPath) {
        var ts = new Date().getTime();
        var printDir = engine.runtimeDir + "/test_fingerprints";
        var outPath = printDir + "/REVEALED_" + ts + ".png";
        revealProc.targetFile = outPath;
        revealProc.command = [
            "sh", "-c",
            'mkdir -p "$1" && ' +
            'magick "$2" -channel B -separate \\( +clone -blur 0x2 \\) -compose Subtract -composite -auto-level -define png:compression-level=1 "$3" && ' +
            'rm -f "$2"',
            "sh", printDir, cropPath, outPath
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
        "cp -f " + ShotState.shQuote(path) + " " + ShotState.shQuote(proofPath) + "; " +
        "cp -f " + ShotState.shQuote(path) + " " + ShotState.shQuote(histImg) + "; " +
        buildJsonEcho("Revealed Proof", histImg, histMeta) + "; " +
        "notify-send -a Quickshot 'Proof Saved' " + ShotState.shQuote(proofPath);

        Quickshell.execDetached(["sh", "-c", cmd]);
    }
}
