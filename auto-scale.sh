#!/bin/bash

# Auto-scaling script based on CPU usage from Prometheus metrics
# This script monitors CPU usage and scales web servers up or down

PROMETHEUS_URL="http://localhost:9090"
SCALE_UP_THRESHOLD=70    # Scale up if CPU > 70%
SCALE_DOWN_THRESHOLD=30  # Scale down if CPU < 30%
MIN_SERVERS=2
MAX_SERVERS=5

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

# Function to scale web servers
scale_servers() {
    local target_count=$1
    local current_count=$(get_current_servers)
    
    if [ "$target_count" -ne "$current_count" ]; then
        echo "Scaling from $current_count to $target_count servers..."
        
        # Update terraform variable
        terraform apply -var="web_server_count=$target_count" -auto-approve
        
        if [ $? -eq 0 ]; then
            echo "Successfully scaled to $target_count servers"
            
            # Wait for new instances to be ready
            sleep 60
            
            # Re-run Ansible to update configurations
            cd ansible && ansible-playbook -i inventory.ini playbook.yml --tags monitoring_config
        else
            echo "Failed to scale servers"
            exit 1
        fi
    else
        echo "No scaling needed. Current: $current_count, Target: $target_count"
    fi
}

# Main monitoring loop
main() {
    echo "Starting auto-scaling monitoring..."
    
    while true; do
        # Get current metrics
        local cpu_usage=$(get_cpu_usage)
        local current_servers=$(get_current_servers)
        
        echo "Current CPU Usage: ${cpu_usage}%, Servers: ${current_servers}"
        
        # Make scaling decisions
        if (( $(echo "$cpu_usage > $SCALE_UP_THRESHOLD" | bc -l) )) && [ "$current_servers" -lt "$MAX_SERVERS" ]; then
            echo "High CPU usage detected. Scaling up..."
            scale_servers $((current_servers + 1))
        elif (( $(echo "$cpu_usage < $SCALE_DOWN_THRESHOLD" | bc -l) )) && [ "$current_servers" -gt "$MIN_SERVERS" ]; then
            echo "Low CPU usage detected. Scaling down..."
            scale_servers $((current_servers - 1))
        fi
        
        # Wait before next check
        sleep 300  # Check every 5 minutes
    done
}

# Check if required tools are installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Please install jq."
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo "bc is required but not installed. Please install bc."
    exit 1
fi

# Run main function
main
