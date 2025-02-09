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

# Function to ensure log file exists
ensure_log_file() {
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
    fi
}

# Function to manage log size
manage_log_file() {
    ensure_log_file
    if [[ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
        tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
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

# Ensure log file exists
ensure_log_file

# Get current metrics
cpu_usage=$(get_cpu_usage)
mem_usage=$(get_memory_usage)
read -r tx_bytes rx_bytes <<<"$(get_network_stats)"

# Debugging output
echo "Logging to: $LOG_FILE"
echo "CPU: $cpu_usage%, Memory: $mem_usage%, Tx: $tx_bytes, Rx: $rx_bytes"

# Handle interactive mode
if [[ -t 0 ]]; then
    cpu_trend=$(get_trend "$cpu_usage" 0)
    mem_trend=$(get_trend "$mem_usage" 1)
    
    echo "Current system metrics:"
    echo -n "CPU usage: current - $cpu_usage%"
    [[ -n "$cpu_trend" ]] && echo " trend - $cpu_trend" || echo ""
    
    echo -n "Memory usage: current - $mem_usage%"
    [[ -n "$mem_trend" ]] && echo " trend - $mem_trend" || echo ""
    
    echo "Tx/Rx bytes: $tx_bytes/$rx_bytes"
else
    manage_log_file
    echo "[$(date +'%a %b %d %H:%M:%S %Z %Y')] $cpu_usage $mem_usage $tx_bytes $rx_bytes" >> "$LOG_FILE"
    echo "Log entry added."  # Debugging message
fi
