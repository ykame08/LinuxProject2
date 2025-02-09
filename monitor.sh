#!/bin/bash

# Enable error handling
set -e

# Config
LOG_FILE="/var/log/monitor.log"
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB in bytes

# Function to check if running as root
check_root() {
    if [[ $(id -u) -ne 0 ]]; then
        echo "Error: This script must be run as root"
        exit 1
    fi
}

# Function to manage log file with error handling
manage_log_file() {
    # Check if directory exists, if not create it
    log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || echo "Error: Cannot create directory $log_dir" && exit 1
    fi

    # Create log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE" || echo "Error: Cannot create log file $LOG_FILE" && exit 1
        chmod 644 "$LOG_FILE" || echo "Error: Cannot set permissions on $LOG_FILE" && exit 1
    fi

    # Check if file is writable
    if [[ ! -w "$LOG_FILE" ]]; then
        echo "Error: Log file $LOG_FILE is not writable"
        exit 1
    fi
    
    # Rotate log if necessary
    if [[ -f "$LOG_FILE" ]]; then
        file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) || {
            echo "Error: Cannot get file size of $LOG_FILE"
            exit 1
        }
        
        if [[ $file_size -gt $MAX_LOG_SIZE ]]; then
            tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" || {
                echo "Error: Cannot rotate log file"
                exit 1
            }
            mv "$LOG_FILE.tmp" "$LOG_FILE" || {
                echo "Error: Cannot complete log rotation"
                exit 1
            }
        fi
    fi
}

# Function to get CPU usage percentage with error handling
get_cpu_usage() {
    local vmstat_output
    vmstat_output=$(vmstat 2>/dev/null) || {
        echo "Error: Cannot get CPU statistics"
        exit 1
    }
    
    read -r -a cpu_usage_a <<<"$(echo "$vmstat_output" | sed -n 3p)"
    cpu_usage="${cpu_usage_a[-3]}"
    if [[ -z "$cpu_usage" ]]; then
        echo "Error: Cannot parse CPU usage"
        exit 1
    fi
    echo $((100 - cpu_usage))
}

# Function to get RAM usage percentage with error handling
get_memory_usage() {
    local free_output
    free_output=$(free 2>/dev/null) || {
        echo "Error: Cannot get memory statistics"
        exit 1
    }
    
    read -r -a mem_info <<<"$(echo "$free_output" | grep Mem)"
    total_mem="${mem_info[1]}"
    used_mem="${mem_info[2]}"
    
    if [[ -z "$total_mem" ]] || [[ -z "$used_mem" ]]; then
        echo "Error: Cannot parse memory usage"
        exit 1
    fi
    
    awk -v used="$used_mem" -v total="$total_mem" 'BEGIN { printf "%.2f", (used * 100) / total }'
}

# Function to get network statistics with error handling
get_network_stats() {
    local found_interface=false
    local tx_bytes=0
    local rx_bytes=0
    
    for iface in /sys/class/net/*; do
        if [[ -d "$iface/device" ]]; then
            tx_bytes=$(cat "$iface/statistics/tx_bytes" 2>/dev/null) || continue
            rx_bytes=$(cat "$iface/statistics/rx_bytes" 2>/dev/null) || continue
            found_interface=true
            break
        fi
    done
    
    if [[ "$found_interface" == "false" ]]; then
        echo "Error: No physical network interface found"
        exit 1
    fi
    
    echo "$tx_bytes $rx_bytes"
}

# Function to write log entry with error handling
write_log_entry() {
    local cpu_usage=$1
    local mem_usage=$2
    local tx_bytes=$3
    local rx_bytes=$4
    
    local timestamp
    timestamp=$(date +'[%a %b %d %H:%M:%S %Z %Y]') || {
        echo "Error: Cannot generate timestamp"
        exit 1
    }
    
    echo "$timestamp $cpu_usage $mem_usage $tx_bytes $rx_bytes" >> "$LOG_FILE" || {
        echo "Error: Cannot write to log file"
        exit 1
    }
}

# Main execution
main() {
    # Check root permissions first
    check_root
    
    # Get current metrics
    local cpu_usage mem_usage tx_bytes rx_bytes
    cpu_usage=$(get_cpu_usage)
    mem_usage=$(get_memory_usage)
    read -r tx_bytes rx_bytes <<<"$(get_network_stats)"
    
    # Handle interactive vs automated mode
    if [[ -t 0 ]]; then
        echo "Current system metrics:"
        echo "CPU usage: current - $cpu_usage%"
        echo "Memory usage: current - $mem_usage%"
        echo "Tx/Rx bytes: $tx_bytes/$rx_bytes"
    else
        manage_log_file
        write_log_entry "$cpu_usage" "$mem_usage" "$tx_bytes" "$rx_bytes"
    fi
}

# Run main function
main
