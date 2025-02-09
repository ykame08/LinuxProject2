#!/bin/bash

BACKUP_DIR="/opt/sysmonitor/backups"
LOG_FILE="/var/log/backup.log"
BACKUP_RETENTION_DAYS=7

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to log messages with timestamp
log_message() {
    echo "[$(date +'%a %b %d %H:%M:%S %Z %Y')] $1" >> "$LOG_FILE"
}

# Function to check if enough disk space is available
check_disk_space() {
    available_space_in_bytes=$(df --output=avail /home | tail -1)
    dir_size_in_bytes=$(du -sb /home | cut -f1)
    
    if (( available_space_in_bytes > dir_size_in_bytes )); then
        return 0
    else
        return 1
    fi
}

# Function to create backup
create_backup() {
    local backup_file_name
    backup_file_name="$(date '+%Y_%m_%d_%H_%M_%S')_home_backup.tar.gz"
    
    if ! check_disk_space; then
        log_message "Error: Not enough disk space available for backup"
        if [[ -t 0 ]]; then
            echo "Error: Not enough disk space for backup"
        fi
        return 1
    fi
    
    if tar czf "$BACKUP_DIR/$backup_file_name" /home 2>/dev/null; then
        log_message "Backup created successfully: $backup_file_name"
        if [[ -t 0 ]]; then
            echo "Backup created successfully: $backup_file_name"
        fi
    else
        log_message "Error: Backup creation failed"
        if [[ -t 0 ]]; then
            echo "Error: Backup creation failed"
        fi
        return 1
    fi
}

# Function to clean old backups (older than 7 days)
clean_old_backups() {
    find "$BACKUP_DIR" -name "*_home_backup.tar.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete
}

# Function to show last 5 backup logs
show_last_logs() {
    if [[ ! -f "$LOG_FILE" ]] || [[ ! -s "$LOG_FILE" ]]; then
        echo "No backup logs available"
        return
    fi
    echo "Last 5 backup logs:"
    tail -n 5 "$LOG_FILE"
}

# Main execution
if [[ -t 0 ]]; then  # Interactive mode
    if [[ $(id -u) -ne 0 ]]; then
        echo "This script must be run as root in interactive mode"
        exit 1
    fi
    
    if [[ $1 == "show_logs" ]]; then
        show_last_logs
    else
        create_backup
    fi
else  # Automated mode
    create_backup
    clean_old_backups
fi
