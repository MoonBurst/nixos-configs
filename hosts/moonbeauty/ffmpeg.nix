{ config, pkgs, ... }:
let
  twitch-stream = pkgs.writeShellScriptBin "twitch-stream" ''
    set -euo pipefail
    PID_FILE="/tmp/twitch-stream.pid"
    LOG_FILE="/tmp/twitch-stream.log"

    # Toggle Off: Check if Twitch stream is active
    if { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; } || pgrep -f "gpu-screen-recorder.*rtmp://live.twitch.tv" > /dev/null; then
      echo "Stopping Twitch stream..."
      pkill -f "gpu-screen-recorder.*rtmp://live.twitch.tv" || true
      rm -f "$PID_FILE"
      ${pkgs.libnotify}/bin/notify-send "Twitch Stream" "Stream stopped" -i media-playback-stop
      exit 0
    fi

    # Check secret key
    SECRET_PATH="${config.sops.secrets.twitch-stream-key.path}"
    if [ ! -f "$SECRET_PATH" ]; then
      echo "Error: Stream key secret not found at $SECRET_PATH" >&2
      ${pkgs.libnotify}/bin/notify-send "Twitch Stream Error" "Secret key missing at $SECRET_PATH" -u critical -i dialog-error
      exit 1
    fi
    STREAM_KEY=$(cat "$SECRET_PATH")

    # Prompt user to click a monitor/screen to stream
    echo "Please click on the monitor you want to stream..."
    MONITOR=$(${pkgs.slurp}/bin/slurp -f "%o" -or) || exit 0

    if [ -z "$MONITOR" ]; then
      echo "No monitor selected. Aborting."
      exit 0
    fi

    # PipeWire Audio Node check (fallback to default audio if custom sink is missing)
    AUDIO_DEVICE="twitch_mix_sink"
    if ! ${pkgs.pipewire}/bin/pw-cli list-objects Node 2>/dev/null | grep -q "twitch_mix_sink"; then
      echo "Warning: twitch_mix_sink PipeWire node not found. Falling back to default_output."
      AUDIO_DEVICE="default_output"
    fi

    ${pkgs.libnotify}/bin/notify-send "Twitch Stream" "Starting Live Stream on $MONITOR..." -i media-record

    # Launch gpu-screen-recorder (AMD hardware encoder with native transform support)
    nohup gpu-screen-recorder \
      -w "$MONITOR" \
      -f 60 \
      -a "$AUDIO_DEVICE" \
      -c flv \
      -k h264 \
      -o "rtmp://live.twitch.tv/app/$STREAM_KEY" > "$LOG_FILE" 2>&1 &

    STREAM_PID=$!
    echo "$STREAM_PID" > "$PID_FILE"

    # Startup validation check (detect instant crashes)
    sleep 1.5
    if ! kill -0 "$STREAM_PID" 2>/dev/null; then
      ${pkgs.libnotify}/bin/notify-send "Twitch Stream Error" "Stream failed to start! Check $LOG_FILE" -u critical -i dialog-error
      rm -f "$PID_FILE"
      exit 1
    fi
  '';

  record-region = pkgs.writeShellScriptBin "record-region" ''
    set -euo pipefail
    PID_FILE="/tmp/record-region.pid"
    LOG_FILE="/tmp/record-region.log"
    TARGET_DIR="/mnt/3TBHDD/Recordings"

    # Toggle Off: Stop active region recording safely with SIGINT (finalizes container)
    if { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; } || pgrep -f "wf-recorder.*Region_" > /dev/null; then
      echo "Stopping region recording..."
      pkill -SIGINT -f "wf-recorder.*Region_" || true
      rm -f "$PID_FILE"
      ${pkgs.libnotify}/bin/notify-send "Region Recorder" "Recording saved to $TARGET_DIR" -i media-playback-stop
      exit 0
    fi

    # Toggle On: Prompt mouse selection using slurp
    GEOM=$(${pkgs.slurp}/bin/slurp) || exit 0
    if [ -z "$GEOM" ]; then
      exit 0
    fi

    # PipeWire Audio Node check (fallback to default audio if custom sink is missing)
    AUDIO_ARG="--audio=twitch_mix_sink.monitor"
    if ! ${pkgs.pipewire}/bin/pw-cli list-objects Node 2>/dev/null | grep -q "twitch_mix_sink"; then
      echo "Warning: twitch_mix_sink PipeWire node not found. Falling back to default audio source."
      AUDIO_ARG="--audio"
    fi

    mkdir -p "$TARGET_DIR"
    OUTPUT_FILE="$TARGET_DIR/Region_$(date +'%Y-%m-%d_%H-%M-%S').mp4"

    ${pkgs.libnotify}/bin/notify-send "Region Recorder" "Recording started..." -i media-record

    # Use libx264 for region recording to avoid VAAPI 180-degree transpose filter crashes
    nohup ${pkgs.wf-recorder}/bin/wf-recorder \
      -g "$GEOM" \
      "$AUDIO_ARG" \
      --codec=libx264 \
      -p preset=ultrafast \
      -p crf=23 \
      --file="$OUTPUT_FILE" > "$LOG_FILE" 2>&1 &

    REC_PID=$!
    echo "$REC_PID" > "$PID_FILE"

    # Startup validation check (detect instant crashes)
    sleep 1.5
    if ! kill -0 "$REC_PID" 2>/dev/null; then
      ${pkgs.libnotify}/bin/notify-send "Region Recorder Error" "Recording failed! Check $LOG_FILE" -u critical -i dialog-error
      rm -f "$PID_FILE"
      exit 1
    fi
  '';

  start-replay-buffer = pkgs.writeShellScriptBin "start-replay-buffer" ''
    set -euo pipefail
    TARGET_DIR="/mnt/3TBHDD/Recordings"
    mkdir -p "$TARGET_DIR"

    echo "=========================================================="
    echo "  Starting GPU Screen Recorder Replay Buffer..."
    echo "  Capturing: DP-1 (2560x1440)"
    echo "  Audio:     Default Output"
    echo "  Buffer size: 60 seconds"
    echo "  Output directory: $TARGET_DIR"
    echo "  Use 'save-replay' to save the buffer."
    echo "=========================================================="

    exec gpu-screen-recorder \
      -w DP-1 \
      -f 60 \
      -a "default_output" \
      -c mp4 \
      -k hevc \
      -r 60 \
      -o "$TARGET_DIR"
  '';

  save-replay = pkgs.writeShellScriptBin "save-replay" ''
    set -euo pipefail
    if pgrep -f "gpu-screen-recorder.*-r" > /dev/null; then
      echo "Saving last 60 seconds to /mnt/3TBHDD/Recordings..."
      ${pkgs.psmisc}/bin/killall -USR1 gpu-screen-recorder
      ${pkgs.libnotify}/bin/notify-send "Replay Saved" "The last 60 seconds have been saved." -i video-x-generic
    else
      echo "Error: gpu-screen-recorder replay buffer is not running." >&2
      ${pkgs.libnotify}/bin/notify-send "Replay Error" "The replay buffer is not currently running." -u critical
      exit 1
    fi
  '';

in {
  sops.secrets.twitch-stream-key = {
    owner = "moonburst";
    group = "users";
    mode = "0400";
  };

  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = [
    twitch-stream
    record-region
    start-replay-buffer
    save-replay
    pkgs.wf-recorder
    pkgs.slurp
    pkgs.ffmpeg-headless
    pkgs.psmisc
    pkgs.libnotify
    pkgs.pipewire
    pkgs.wireplumber
  ];
}
