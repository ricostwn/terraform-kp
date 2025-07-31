# Ansible runner script for Windows
# This script properly handles Ansible execution on Windows

param(
    [string]$Action = "run",
    [string]$Inventory = "inventory.ini",
    [string]$Playbook = "playbook.yml",
    [string]$Limit = "",
    [switch]$Check = $false,
    [switch]$Verbose = $false
)

function Write-Banner {
    param([string]$Message)
    Write-Host "`n" + ("="*60) -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host ("="*60) -ForegroundColor Cyan
}

function Test-AnsibleRequirements {
    Write-Banner "Checking Ansible Requirements"
    
    # Check if Ansible is installed
    if (-not (Get-Command ansible-playbook -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Ansible not found" -ForegroundColor Red
        Write-Host "Install Ansible with: pip install ansible" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "✓ Ansible found" -ForegroundColor Green
    }
    
    # Check if inventory exists
    if (-not (Test-Path $Inventory)) {
        Write-Host "❌ Inventory file not found: $Inventory" -ForegroundColor Red
        Write-Host "Make sure Terraform has been applied successfully" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "✓ Inventory file found" -ForegroundColor Green
    }
    
    # Check if playbook exists
    if (-not (Test-Path $Playbook)) {
        Write-Host "❌ Playbook not found: $Playbook" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✓ Playbook found" -ForegroundColor Green
    }
}

function Test-Connectivity {
    Write-Host "Testing SSH connectivity to all servers..." -ForegroundColor Yellow
    
    try {
        # Use ansible ping module to test connectivity
        if ($Limit) {
            $result = ansible $Limit -i $Inventory -m ping --one-line 2>&1
        } else {
            $result = ansible all -i $Inventory -m ping --one-line 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ All servers are reachable" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Some servers are not reachable" -ForegroundColor Red
            Write-Host "Error: $result" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "❌ Connectivity test failed: $_" -ForegroundColor Red
        return $false
    }
}

function Start-AnsiblePlaybook {
    Write-Banner "Running Ansible Playbook"
    
    # Build ansible-playbook command
    $cmd = "ansible-playbook -i $Inventory"
    
    if ($Limit) {
        $cmd += " --limit $Limit"
    }
    
    if ($Check) {
        $cmd += " --check"
        Write-Host "Running in check mode (dry run)" -ForegroundColor Yellow
    }
    
    if ($Verbose) {
        $cmd += " -v"
    }
    
    $cmd += " $Playbook"
    
    Write-Host "Executing: $cmd" -ForegroundColor Cyan
    
    # Execute ansible-playbook
    try {
        Invoke-Expression $cmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Ansible playbook completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "❌ Ansible playbook failed with exit code $LASTEXITCODE" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Failed to execute ansible-playbook: $_" -ForegroundColor Red
    }
}

function Show-ServerStatus {
    Write-Banner "Server Status"
    
    Write-Host "Checking Docker containers on all servers..." -ForegroundColor Yellow
    ansible all -i $Inventory -a "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" --one-line
    
    Write-Host "`nChecking system status..." -ForegroundColor Yellow
    ansible all -i $Inventory -a "uptime" --one-line
}

function Show-Help {
    Write-Host @"
Ansible Runner for Windows

Usage: .\run-ansible.ps1 [options]

Actions:
  -Action run         Run the playbook (default)
  -Action test        Test connectivity only
  -Action status      Show server status
  -Action help        Show this help

Options:
  -Inventory <file>   Ansible inventory file (default: inventory.ini)
  -Playbook <file>    Ansible playbook file (default: playbook.yml)
  -Limit <pattern>    Limit execution to specific hosts/groups
  -Check              Run in check mode (dry run)
  -Verbose            Enable verbose output

Examples:
  .\run-ansible.ps1                                    # Run full playbook
  .\run-ansible.ps1 -Action test                       # Test connectivity
  .\run-ansible.ps1 -Limit monitoring_server           # Run only on monitoring server
  .\run-ansible.ps1 -Check -Verbose                    # Dry run with verbose output
  .\run-ansible.ps1 -Action status                     # Check server status

"@ -ForegroundColor White
}

# Change to ansible directory
if (Test-Path "ansible") {
    Set-Location ansible
}

# Main execution
switch ($Action.ToLower()) {
    "run" {
        Test-AnsibleRequirements
        if (Test-Connectivity) {
            Start-AnsiblePlaybook
        } else {
            Write-Host "Connectivity test failed. Please check your servers and try again." -ForegroundColor Red
            exit 1
        }
    }
    "test" {
        Test-AnsibleRequirements
        Test-Connectivity
    }
    "status" {
        Show-ServerStatus
    }
    "help" {
        Show-Help
    }
    default {
        Write-Host "Unknown action: $Action" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
