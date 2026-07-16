{ config, pkgs, ... }:
let
  twitch-stream = pkgs.writeShellScriptBin "twitch-stream" ''
    set -euo pipefail
    SECRET_PATH="${config.sops.secrets.twitch-stream-key.path}"
    if [ ! -f "$SECRET_PATH" ]; then
      echo "Error: Stream key secret not found at $SECRET_PATH" >&2
      exit 1
    fi
    STREAM_KEY=$(cat "$SECRET_PATH")
    echo "=========================================================="
    echo "  Starting headless Twitch Livestream..."
    echo "  Capturing: Wayland Screen + Unified Pipewire Master Mix"
    echo "  Encoder:   AMD 7900 XTX Dedicated Hardware AV1 Core"
    echo "  Press Ctrl+C to stop broadcasting."
    echo "=========================================================="
    exec ${pkgs.wf-recorder}/bin/wf-recorder \
      --audio=twitch_mix_sink.monitor \
      --codec=av1_vaapi \
      --device=/dev/dri/renderD128 \
      --filter="scale_vaapi=format=nv12:out_range=full" \
      --muxer=flv \
      --pcodec="b=6000k:maxrate=6000k:bufsize=6000k:g=120:bf=0:c:a=aac:ar=48000:b:a=160k" \
      --file="rtmp://live.twitch.tv/app/$STREAM_KEY"
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

    # Changed -k av1 to -k hevc for better video player compatibility
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
    # -f is used here to match against the full command name to bypass the 15-character limit
    if pgrep -f "gpu-screen-recorder" > /dev/null; then
      echo "Saving last 60 seconds to /mnt/3TBHDD/Recordings..."
      ${pkgs.psmisc}/bin/killall -USR1 gpu-screen-recorder
      ${pkgs.libnotify}/bin/notify-send "Replay Saved" "The last 60 seconds have been saved." -i video-x-generic
    else
      echo "Error: gpu-screen-recorder is not running." >&2
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
    start-replay-buffer
    save-replay
    pkgs.wf-recorder
    pkgs.ffmpeg-headless
    pkgs.psmisc
    pkgs.libnotify
  ];
}
