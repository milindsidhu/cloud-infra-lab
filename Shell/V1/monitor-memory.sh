#!/bin/bash

# avail_mem=$(top -l 1 | grep PhysMem | awk '{print $2}' | sed 's/M//')

# if [ $avail_mem -lt 3000 ]; then
#     echo "Memory is running low! Available Memory: $avail_mem MB"
# else
#     echo "Memory is sufficient! Available Memory: $avail_mem MB"
# fi

# avail_mem_percent=$(top -l 1 | grep PhysMem | awk '{print $6}' | sed 's/%//')

# if [ $avail_mem_percent -lt 10 ]; then
#     echo "Memory is running low! Available Memory: $avail_mem_percent%"
# else
#     echo "Memory is sufficient! Available Memory: $avail_mem_percent%"
# fi


total_mem=$(sysctl -n hw.memsize)
total_mem_mb=$((total_mem / 1024 / 1024))

free_mem_pages=$(vm_stat | grep 'Pages free:' | awk '{print $3}' | sed 's/\.//')
free_mem_mb=$((free_mem_pages * 4 / 1024))

avail_mem_percent=$((free_mem_mb * 100 / total_mem_mb))

if [ $avail_mem_percent -lt 10 ]; then
    echo "Memory is running low! Available Memory: $avail_mem_percent%"
else
    echo "Memory is sufficient! Available Memory: $avail_mem_percent%"
fi

# Get total memory in MB
total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_mb=$((total_mem_kb / 1024))

# Get free memory in MB (including buffers/cache)
free_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
free_mem_mb=$((free_mem_kb / 1024))

# Calculate available memory percentage
avail_mem_percent=$((free_mem_mb * 100 / total_mem_mb))

# Display memory status
if [ "$avail_mem_percent" -lt 10 ]; then
    echo "Memory is running low! Available Memory: ${avail_mem_percent}%"
else
    echo "Memory is sufficient! Available Memory: ${avail_mem_percent}%"
fi