# Auto-scaling script for Windows PowerShell
# This script monitors CPU usage and scales web servers up or down

param(
    [string]$PrometheusUrl = "http://localhost:9090",
    [int]$ScaleUpThreshold = 70,
    [int]$ScaleDownThreshold = 30,
    [int]$MinServers = 2,
    [int]$MaxServers = 5,
    [int]$CheckInterval = 300
)

function Get-CpuUsage {
    param([string]$Url)
    
    try {
        $query = "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=`"idle`"}[5m])) * 100)"
        $response = Invoke-RestMethod -Uri "$Url/api/v1/query?query=$query" -Method Get
        
        if ($response.data.result.Count -gt 0) {
            return [double]$response.data.result[0].value[1]
        }
        return 0
    }
    catch {
        Write-Warning "Failed to get CPU usage: $_"
        return 0
    }
}

function Get-CurrentServerCount {
    try {
        $output = terraform output -json web_servers_names | ConvertFrom-Json
        return $output.Count
    }
    catch {
        Write-Warning "Failed to get current server count: $_"
        return 2
    }
}

function Set-ServerScale {
    param([int]$TargetCount)
    
    $currentCount = Get-CurrentServerCount
    
    if ($TargetCount -ne $currentCount) {
        Write-Host "Scaling from $currentCount to $TargetCount servers..." -ForegroundColor Yellow
        
        # Update terraform variable and apply
        terraform apply -var="web_server_count=$TargetCount" -auto-approve
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully scaled to $TargetCount servers" -ForegroundColor Green
            
            # Wait for new instances to be ready
            Start-Sleep 60
            
            # Re-run Ansible to update configurations
            Set-Location ansible
            ansible-playbook -i inventory.ini playbook.yml --tags monitoring_config
            Set-Location ..
        }
        else {
            Write-Error "Failed to scale servers"
            exit 1
        }
    }
    else {
        Write-Host "No scaling needed. Current: $currentCount, Target: $TargetCount" -ForegroundColor Green
    }
}

function Start-AutoScaling {
    Write-Host "Starting auto-scaling monitoring..." -ForegroundColor Cyan
    Write-Host "Scale Up Threshold: $ScaleUpThreshold%" -ForegroundColor Cyan
    Write-Host "Scale Down Threshold: $ScaleDownThreshold%" -ForegroundColor Cyan
    Write-Host "Min Servers: $MinServers, Max Servers: $MaxServers" -ForegroundColor Cyan
    Write-Host "Check Interval: $CheckInterval seconds" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
    
    while ($true) {
        try {
            # Get current metrics
            $cpuUsage = Get-CpuUsage -Url $PrometheusUrl
            $currentServers = Get-CurrentServerCount
            
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "[$timestamp] CPU Usage: $([math]::Round($cpuUsage, 2))%, Servers: $currentServers" -ForegroundColor White
            
            # Make scaling decisions
            if ($cpuUsage -gt $ScaleUpThreshold -and $currentServers -lt $MaxServers) {
                Write-Host "High CPU usage detected. Scaling up..." -ForegroundColor Red
                Set-ServerScale -TargetCount ($currentServers + 1)
            }
            elseif ($cpuUsage -lt $ScaleDownThreshold -and $currentServers -gt $MinServers) {
                Write-Host "Low CPU usage detected. Scaling down..." -ForegroundColor Blue
                Set-ServerScale -TargetCount ($currentServers - 1)
            }
            
            # Wait before next check
            Start-Sleep $CheckInterval
        }
        catch {
            Write-Error "Error in monitoring loop: $_"
            Start-Sleep 30
        }
    }
}

# Check if required tools are available
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform is required but not found in PATH"
    exit 1
}

if (-not (Get-Command ansible-playbook -ErrorAction SilentlyContinue)) {
    Write-Error "Ansible is required but not found in PATH"
    exit 1
}

# Start the auto-scaling monitoring
Start-AutoScaling
