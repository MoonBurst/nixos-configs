#!/usr/bin/env bash

RCLONE_REMOTE="NextCloud"
NEXTCLOUD_USER="MoonBurst"
LOG_FILE="$HOME/rclone_sync.log"


declare -a FOLDERS_TO_SYNC
FOLDERS_TO_SYNC=(
    "$HOME/Music"
    "$HOME/Pictures"
    "$HOME/scripts"
    "$HOME/.local/share/pass"
    "$HOME/.config/zsh"
    # Can't do single files, folders only.
)
RCLONE_OPTIONS=(
    # --stats 5m : Print status update every 5 minutes
    --stats 5m
    # --stats-one-line : Keep status updates on a single line
    --stats-one-line
    --log-file="$LOG_FILE"
    # --fast-list : Reduces API calls
    --fast-list
    # --ignore-times : Ignore differences in modification times. 
    #--ignore-times
    --retries 10
    --checksum
    # --checkers = number, for parallel transfers
    --checkers 32
    --transfers 8
    --verbose
    # --copy-links copy symlinks
    --copy-links
    # --dry-run
)

echo "--- Starting Rclone Sync at $(date) ---" >> "$LOG_FILE"

for LOCAL_SRC in "${FOLDERS_TO_SYNC[@]}"; do
    FOLDER_NAME=$(basename "$LOCAL_SRC")
    REMOTE_DST="$FOLDER_NAME"
    
    echo "  -> Syncing: $LOCAL_SRC to $RCLONE_REMOTE:$REMOTE_DST" >> "$LOG_FILE"
    rclone mkdir "$RCLONE_REMOTE:$REMOTE_DST"
    rclone sync "$LOCAL_SRC" "$RCLONE_REMOTE:$REMOTE_DST" "${RCLONE_OPTIONS[@]}"
    
    # Check the exit status of the rclone command
    if [ $? -eq 0 ]; then
        echo "  -> SUCCESS: $LOCAL_SRC sync complete." >> "$LOG_FILE"
    else
        echo "  -> ERROR: $LOCAL_SRC sync FAILED (Exit Code $?). Check log file for details." >> "$LOG_FILE"
    fi

done

echo "--- Rclone Sync Complete at $(date) ---" >> "$LOG_FILE"
