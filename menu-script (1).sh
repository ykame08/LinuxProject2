#!/bin/bash

# Check if script runs interactively
if [[ ! -t 0 ]]; then
    echo "This script must be run interactively"
    exit 1
fi

# Check if running as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Function to get total number of running processes
get_process_count() {
    n=$(($(ps auxh | wc -l) - 2))
    echo "Total number of running processes: $n"
}

# Main menu
while true; do
    clear
    echo "System Monitoring and Maintenance Menu"
    echo "======================================"
    echo "1. Show current system metrics"
    echo "2. Show last 5 backup logs"
    echo "3. Perform manual backup"
    echo "4. Perform disk cleanup"
    echo "5. Show total running processes"
    echo "6. Exit"
    echo
    read -rp "Select an option (1-6): " choice
    echo

    case $choice in
        1)
            /usr/local/bin/monitor.sh
            ;;
        2)
            /usr/local/bin/backup.sh show_logs
            ;;
        3)
            /usr/local/bin/backup.sh
            ;;
        4)
            /usr/local/bin/cleanup.sh
            ;;
        5)
            get_process_count
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac

    echo
    read -rp "Press Enter to continue..."
done
