#!/bin/bash

# Auto-scaling script based on CPU usage from Prometheus metrics
# This script monitors CPU usage and scales web servers up or down

PROMETHEUS_URL="http://localhost:9090"
SCALE_UP_THRESHOLD=75    # Scale up if CPU > 75% (hysteresis)
SCALE_DOWN_THRESHOLD=25  # Scale down if CPU < 25% (hysteresis)
MIN_SERVERS=2
MAX_SERVERS=5
COOLDOWN_PERIOD=600      # 10 minutes cooldown (in seconds)
LOG_FILE="/var/log/auto-scale.log"
LAST_SCALE_FILE="/tmp/last_scale_time"

# Function to write log
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

# Function to get current CPU usage from Prometheus
get_cpu_usage() {
    local query="100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
    local result=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${query}" | jq -r '.data.result[0].value[1]' 2>/dev/null)
    echo "${result:-0}"
}

# Function to get current number of web servers
get_current_servers() {
    terraform output -json web_servers_names | jq -r '. | length'
}

# Check cooldown
check_cooldown() {
    if [ -f "$LAST_SCALE_FILE" ]; then
        local last_scale_time=$(cat "$LAST_SCALE_FILE")
        local now=$(date +%s)
        local diff=$((now - last_scale_time))
        if [ "$diff" -lt "$COOLDOWN_PERIOD" ]; then
            log "Cooldown active: wait $((COOLDOWN_PERIOD - diff))s more before next scaling."
            return 1
        fi
    fi
    return 0
}

# Function to scale web servers
scale_servers() {
    local target_count=$1
    local current_count=$(get_current_servers)
    
    if [ "$target_count" -ne "$current_count" ]; then
        log "Scaling from $current_count to $target_count servers..."
        
        terraform apply -var="web_server_count=$target_count" -auto-approve
        if [ $? -eq 0 ]; then
            log "✅ Successfully scaled to $target_count servers"
            
            # Save last scale time
            date +%s > "$LAST_SCALE_FILE"
            
            # Wait for new instances to be ready
            sleep 60
            
            # Re-run Ansible to update configurations
            cd ansible && ansible-playbook -i inventory.ini playbook.yml --tags monitoring_config
        else
            log "❌ Failed to scale servers"
            exit 1
        fi
    else
        log "No scaling needed. Current: $current_count, Target: $target_count"
    fi
}

# Main monitoring loop
main() {
    log "Starting auto-scaling monitoring..."
    
    while true; do
        local cpu_usage=$(get_cpu_usage)
        local current_servers=$(get_current_servers)
        
        log "Current CPU Usage: ${cpu_usage}%, Servers: ${current_servers}"
        
        # Scaling decision with hysteresis + cooldown
        if (( $(echo "$cpu_usage > $SCALE_UP_THRESHOLD" | bc -l) )) && [ "$current_servers" -lt "$MAX_SERVERS" ]; then
            if check_cooldown; then
                log "High CPU usage detected. Scaling up..."
                scale_servers $((current_servers + 1))
            fi
        elif (( $(echo "$cpu_usage < $SCALE_DOWN_THRESHOLD" | bc -l) )) && [ "$current_servers" -gt "$MIN_SERVERS" ]; then
            if check_cooldown; then
                log "Low CPU usage detected. Scaling down..."
                scale_servers $((current_servers - 1))
            fi
        fi
        
        sleep 300  # Check every 5 minutes
    done
}

# Check if required tools are installed
for tool in jq bc terraform ansible-playbook curl; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is required but not installed."
        exit 1
    fi
done

# Run main function
main
