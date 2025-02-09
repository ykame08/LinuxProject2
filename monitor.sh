#!/bin/bash

# Config
LOG_FILE="/var/log/monitor.log"
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB in bytes

# Check if user is root
if [ "$(id -u)" -ne 0 ]; then
    echo "You need to run this script as root."
    exit 1
fi

# Function to manage log size
manage_log_file() {
    if [[ -f "$LOG_FILE" ]]; then
        local file_size
        file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")
        
        if [[ $file_size -gt $MAX_LOG_SIZE ]]; then
            tail -n 1000 "$LOG_FILE" | sudo tee "$LOG_FILE.tmp" > /dev/null
            sudo mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
}

# Function to get CPU usage percentage
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}'
}

# Function to get RAM usage percentage
get_memory_usage() {
    free | grep Mem | awk '{print $3/$2 * 100.0}'
}

# Function to get network statistics
get_network_stats() {
    rx_bytes=$(cat /sys/class/net/ens33/statistics/rx_bytes)
    tx_bytes=$(cat /sys/class/net/ens33/statistics/tx_bytes)
    echo "$tx_bytes $rx_bytes"
}

# Function to determine trend (rise or fall)
get_trend() {
    local current_value=$1
    local metric_index=$2
    
    if [[ ! -s "$LOG_FILE" ]]; then
        echo ""
        return
    fi
    
    read -r -a last_log_entry <<<"$(tail -1 "$LOG_FILE" | cut -d ']' -f 2)"
    local last_value="${last_log_entry[$metric_index]}"
    
    if awk -v curr="$current_value" -v last="$last_value" 'BEGIN { exit !(curr > last) }'; then
        echo "rise"
    else
        echo "fall"
    fi
}

# Get current metrics
CPU=$(get_cpu_usage)
MEM=$(get_memory_usage)
read -r TX RX <<<"$(get_network_stats)"
DATE=$(date "+%Y-%m-%d %H:%M:%S")

# Manage log file size before writing
manage_log_file

# Write to log
echo "[$DATE] $CPU% $MEM% $TX $RX" >> $LOG_FILE

# Handle interactive mode
if [[ -t 0 ]]; then
    # Get trends
    cpu_trend=$(get_trend "$CPU" 0)
    mem_trend=$(get_trend "$MEM" 1)
    
    echo "Current system metrics:"
    echo -n "CPU usage: current - $CPU%"
    [[ -n "$cpu_trend" ]] && echo " trend - $cpu_trend" || echo ""
    
    echo -n "Memory usage: current - $MEM%"
    [[ -n "$mem_trend" ]] && echo " trend - $mem_trend" || echo ""
    
    echo "Tx/Rx bytes: $TX/$RX"
    
    LAST_LINE=$(tail -1 $LOG_FILE 2>/dev/null)
    echo "Last log entry: $LAST_LINE"
fi
