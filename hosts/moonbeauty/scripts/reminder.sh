#!/usr/bin/env bash

# Function to display error messages
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Set the environment variables for notify-send
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

# Construct the full file path dynamically
FILE_PATH="$HOME/scripts/cron_scripts/reminder_dates.txt"

# Check if the input file exists
if [[ ! -f $FILE_PATH ]]; then
    error_exit "The file '$FILE_PATH' does not exist."
fi

# Read the file and process each line
while IFS=: read -r date days_and_message; do
    # Skip empty lines and comments
    if [[ -z $date || -z $days_and_message || $date == \#* ]]; then
        continue
    fi

    # Validate the date format
    if ! [[ $date =~ ^[0-9]{1,2}-[0-9]{1,2}$ ]]; then
        error_exit "Invalid date format '$date'. Expected format: MM-DD."
    fi

    # Extract days in advance and message
    days_in_advance=$(echo "$days_and_message" | grep -o '^[0-9]*')
    if [[ $days_and_message == *\"+ ]]; then
        is_urgent=true
        message=$(echo "$days_and_message" | sed -e 's/^[0-9]*"//' -e 's/"+$//') # Remove quotes and `+` at the end
    else
        is_urgent=false
        message=$(echo "$days_and_message" | sed -e 's/^[0-9]*"//' -e 's/"$//') # Remove closing quotes
    fi

    # Validate days_in_advance
    if ! [[ $days_in_advance =~ ^[0-9]+$ ]]; then
        error_exit "Invalid number of days in advance '$days_in_advance'. It should be a positive integer."
    fi

    # Extract day and month
    IFS='-' read -r month day <<< "$date"

    # Calculate today's date
    today_date=$(date +%Y-%m-%d)

    # Notify for the date and days in advance
    for ((i=0; i<=days_in_advance; i++)); do
        # Calculate the target notification date
        notification_date=$(date -d "$month/$day -$i days" +%Y-%m-%d 2>/dev/null || error_exit "Invalid date '$date'.")

        # Compare notification_date with today_date
        if [[ $(date -d "$notification_date" +%s) -eq $(date -d "$today_date" +%s) ]]; then
            if [[ $is_urgent == true ]]; then
                notify-send -u critical "Reminder" "$message is in $i days!"
            else
                notify-send "Reminder" "$message is in $i days."
            fi
        fi
    done
done < $FILE_PATH
