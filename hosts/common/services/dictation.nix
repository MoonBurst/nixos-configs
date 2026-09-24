{ config, pkgs, ... }:

let
  dictateScript = pkgs.writeShellScriptBin "dictate" ''
    set -euo pipefail

    PID_FILE="/tmp/dictate.pid"
    AUDIO_FILE="/tmp/dictate.wav"
    MODEL_DIR="$HOME/.local/share/whisper-models"
    # Upgraded to small.en (244M parameters) for superior homophone & grammatical context
    MODEL="$MODEL_DIR/ggml-small.en.bin"

    # 1. Download small.en model on first use if missing (~460MB)
    if [ ! -f "$MODEL" ]; then
      mkdir -p "$MODEL_DIR"
      ${pkgs.libnotify}/bin/notify-send -a "Dictation" -i audio-input-microphone "Downloading Whisper Model" "Downloading ~460MB small.en high-context model..."
      ${pkgs.curl}/bin/curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin" -o "$MODEL.tmp"
      mv "$MODEL.tmp" "$MODEL"
    fi

    # 2. Toggle Stop: If PID file exists, stop listening and transcribe
    if [ -f "$PID_FILE" ]; then
      REC_PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
      rm -f "$PID_FILE"

      if [ -n "$REC_PID" ] && kill -0 "$REC_PID" 2>/dev/null; then
        kill -SIGINT "$REC_PID" 2>/dev/null || true
        wait "$REC_PID" 2>/dev/null || true
      fi

      ${pkgs.libnotify}/bin/notify-send -a "Dictation" -i audio-input-microphone -t 2000 "⏳ Transcribing..." "Analyzing context & grammar..."

      if [ -f "$AUDIO_FILE" ] && [ -s "$AUDIO_FILE" ]; then
        # --beam-size 5: Looks ahead across the full sentence to resolve homophones (right vs write)
        # --prompt: Primes the neural net for proper literary grammar and idioms
        TEXT=$(${pkgs.whisper-cpp}/bin/whisper-cli \
          -m "$MODEL" \
          -f "$AUDIO_FILE" \
          --no-timestamps \
          -nt \
          --beam-size 5 \
          --prompt "Proper English grammar, capitalization, idioms, and punctuation." \
          2>/dev/null | tr '\n' ' ' | sed 's/^[ \t]*//;s/[ \t]*$//')

        if [ -n "$TEXT" ]; then
          printf "%s" "$TEXT" | ${pkgs.wl-clipboard}/bin/wl-copy
          sleep 0.15
          ${pkgs.wtype}/bin/wtype "$TEXT " || true
          ${pkgs.libnotify}/bin/notify-send -a "Dictation" -i audio-input-microphone -t 3000 "✅ Dictated" "$TEXT"
        else
          ${pkgs.libnotify}/bin/notify-send -a "Dictation" -i audio-input-microphone -t 2000 "Dictation" "No speech detected."
        fi
        rm -f "$AUDIO_FILE"
      else
        ${pkgs.libnotify}/bin/notify-send -a "Dictation" -i dialog-warning -t 2500 "Dictation Error" "No audio was captured. Check microphone."
      fi
      exit 0
    fi

    # 3. Toggle Start: Begin recording from default microphone
    rm -f "$AUDIO_FILE"
    ${pkgs.libnotify}/bin/notify-send -a "Dictation" -i media-record -t 30000 "🔴 Recording Voice..." "Speak now... press SUPER+v to finish."

    if command -v pw-record >/dev/null 2>&1; then
      pw-record --rate 16000 --channels 1 --format s16 "$AUDIO_FILE" &
      REC_PID=$!
    else
      ${pkgs.ffmpeg-headless}/bin/ffmpeg -nostdin -y -f pulse -i default -t 30 -ar 16000 -ac 1 "$AUDIO_FILE" -loglevel quiet &
      REC_PID=$!
    fi

    echo "$REC_PID" > "$PID_FILE"
  '';
in
{
  environment.systemPackages = [
    dictateScript
    pkgs.whisper-cpp
    pkgs.ffmpeg-headless
    pkgs.wtype
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.pipewire
  ];
}
