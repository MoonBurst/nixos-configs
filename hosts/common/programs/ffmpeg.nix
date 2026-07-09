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
    echo "  Encoder:   AMD GPU (vaapi)"
    echo "  Press Ctrl+C to stop broadcasting."
    echo "=========================================================="

    exec ${pkgs.wf-recorder}/bin/wf-recorder \
      --audio=twitch_mix_sink.monitor \
      --codec=h264_vaapi \
      --device=/dev/dri/renderD128 \
      --filter="scale_vaapi=format=nv12:out_range=full,transpose_vaapi=dir=clock,transpose_vaapi=dir=clock" \
      --muxer=flv \
      --pcodec="b=6000k:maxrate=6000k:bufsize=6000k:g=120:bf=0:c:a=aac:ar=48000:b:a=160k" \
      --file="rtmp://live.twitch.tv/app/$STREAM_KEY"
  '';
in {
  sops.secrets.twitch-stream-key = {
    owner = "moonburst";
    group = "users";
    mode = "0400";
  };

  environment.systemPackages = [
    twitch-stream
    pkgs.wf-recorder
    pkgs.ffmpeg-headless
  ];
}
