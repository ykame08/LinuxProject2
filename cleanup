#!/bin/bash

# Constants
DAYS_THRESHOLD=17
SIZE_THRESHOLD=$((10 * 1024 * 1024))  # 10 MiB in bytes
CLEANUP_DIRS=("/tmp" "/var/tmp" "/var/log")

# Function to get total size of files to be deleted
get_files_size() {
    local dir=$1
    local total_size=0
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            size=$(stat -c %s "$file")
            total_size=$((total_size + size))
        fi
    done < <(find "$dir" -type f -mtime +"$DAYS_THRESHOLD")
    
    echo "$total_size"
}

# Function to cleanup directory
cleanup_directory() {
    local dir=$1
    
    if [[ ! -d "$dir" ]]; then
        echo "Directory $dir does not exist"
        return
    fi
    
    local total_size
    total_size=$(get_files_size "$dir")
    
    # If running interactively and size is large, ask for confirmation
    if [[ -t 0 ]] && [[ $total_size -gt $SIZE_THRESHOLD ]]; then
        local size_mb=$((total_size / 1024 / 1024))
        read -rp "About to delete $size_mb MiB from $dir. Continue? (y/n): " confirm
        if [[ $confirm != "y" ]]; then
            echo "Skipping cleanup of $dir"
            return
        fi
    fi
    
    # Delete files older than threshold
    find "$dir" -type f -mtime +"$DAYS_THRESHOLD" -delete 2>/dev/null
    echo "Cleaned up files older than $DAYS_THRESHOLD days in $dir"
}

# Main execution
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Process each directory
for dir in "${CLEANUP_DIRS[@]}"; do
    cleanup_directory "$dir"
done
