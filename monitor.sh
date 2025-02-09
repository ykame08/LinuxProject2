#!/bin/bash

# Check if running as root in interactive mode
if [[ -t 0 ]]; then
    if [[ $(id -u) -ne 0 ]]; then
        echo "This script must be run as root in interactive mode"
        exit 1
    fi
fi

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

# Get current metrics
cpu_usage=$(get_cpu_usage)
mem_usage=$(get_memory_usage)
read -r tx_bytes rx_bytes <<<"$(get_network_stats)"

# Save log using echo
LOG_FILE="/var/log/monitor.log"
echo "[$(date +'%a %b %d %H:%M:%S %Z %Y')] $cpu_usage $mem_usage $tx_bytes $rx_bytes" >> "$LOG_FILE"
