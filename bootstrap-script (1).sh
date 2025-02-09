#!/bin/bash

# Check if script runs as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

# Copy scripts to /usr/local/bin
for script in monitor.sh backup.sh cleanup.sh menu.sh; do
    cp -f "$script" "/usr/local/bin/$script"
    chmod +x "/usr/local/bin/$script"
done

# Create cron jobs while preserving existing ones
(
    # Print existing crontab
    crontab -l 2>/dev/null

    # Add our new jobs
    # Run monitor.sh every hour at minute 0
    echo "0 * * * * /usr/local/bin/monitor.sh"
    
    # Run backup.sh on 4th and 20th of every month at midnight
    echo "0 0 4,20 * * /usr/local/bin/backup.sh"
    
    # Run cleanup.sh once a month (first day of each month at midnight)
    echo "0 0 1 * * /usr/local/bin/cleanup.sh"
) | crontab -

echo "Installation completed successfully!"
