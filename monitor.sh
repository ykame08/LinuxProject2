#!/bin/bash

# Check if running as root in interactive mode
if [[ -t 0 ]]; then
    if [[ $(id -u) -ne 0 ]]; then
        echo "This script must be run as root in interactive mode"
        exit 1
    fi
fi

# Config
LOG_FILE="/var/log/monitor.log"
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB in bytes

# Ensure log directory and file exist with proper permissions
create_log_file() {
    # Create directory if it doesn't exist
    sudo mkdir -p /var/log
    
    # Create log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
    fi
}

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
    read -r -a cpu_usage_a <<<"$(vmstat | sed -n 3p)"
    cpu_usage="${cpu_usage_a[-3]}"
    echo $((100 - cpu_usage))
}

# Function to get RAM usage percentage
get_memory_usage() {
    read -r -a mem_info <<<"$(free | grep Mem)"
    total_mem="${mem_info[1]}"
    used_mem="${mem_info[2]}"
    awk -v used="$used_mem" -v total="$total_mem" 'BEGIN { printf "%.2f", (used * 100) / total }'
}

# Function to get network statistics for physical interface
get_network_stats() {
    for iface in /sys/class/net/*; do
        if [[ -d "$iface/device" ]]; then
            tx_bytes=$(cat "$iface/statistics/tx_bytes")
            rx_bytes=$(cat "$iface/statistics/rx_bytes")
            echo "$tx_bytes $rx_bytes"
            break
        fi
    done
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

# Function to write log entry
write_log_entry() {
    local timestamp=$(date +'[%a %b %d %H:%M:%S %Z %Y]')
    local cpu_usage=$1
    local mem_usage=$2
    local tx_bytes=$3
    local rx_bytes=$4
    
    echo "$timestamp $cpu_usage $mem_usage $tx_bytes $rx_bytes" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Get current metrics
cpu_usage=$(get_cpu_usage)
mem_usage=$(get_memory_usage)
read -r tx_bytes rx_bytes <<<"$(get_network_stats)"

# Handle interactive mode
if [[ -t 0 ]]; then
    # Get trends
    cpu_trend=$(get_trend "$cpu_usage" 0)
    mem_trend=$(get_trend "$mem_usage" 1)
    
    echo "Current system metrics:"
    echo -n "CPU usage: current - $cpu_usage%"
    [[ -n "$cpu_trend" ]] && echo " trend - $cpu_trend" || echo ""
    
    echo -n "Memory usage: current - $mem_usage%"
    [[ -n "$mem_trend" ]] && echo " trend - $mem_trend" || echo ""
    
    echo "Tx/Rx bytes: $tx_bytes/$rx_bytes"
else
    # Create and manage log file
    create_log_file
    manage_log_file
    
    # Write metrics to log
    write_log_entry "$cpu_usage" "$mem_usage" "$tx_bytes" "$rx_bytes"
fi
