# Deployment script for the scalable web server infrastructure
# This script helps deploy and manage the infrastructure

param(
    [string]$Action = "deploy",
    [string]$ProjectId = "",
    [int]$WebServerCount = 2,
    [switch]$AutoApprove = $false
)

function Write-Banner {
    param([string]$Message)
    Write-Host "`n" + ("="*60) -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host ("="*60) -ForegroundColor Cyan
}

function Test-Prerequisites {
    Write-Banner "Checking Prerequisites"
    
    $tools = @("terraform", "ansible", "gcloud")
    $missing = @()
    
    foreach ($tool in $tools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $missing += $tool
        } else {
            Write-Host "✓ $tool found" -ForegroundColor Green
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "❌ Missing tools: $($missing -join ', ')" -ForegroundColor Red
        Write-Host "Please install the missing tools and try again." -ForegroundColor Yellow
        exit 1
    }
    
    # Check for SSH key
    $sshKeyPath = "~/.ssh/id_ed25519"
    if (-not (Test-Path $sshKeyPath)) {
        Write-Host "❌ SSH key not found at $sshKeyPath" -ForegroundColor Red
        Write-Host "Generate SSH key with: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "✓ SSH key found" -ForegroundColor Green
    }
    
    # Check for terraform.tfvars
    if (-not (Test-Path "terraform.tfvars")) {
        Write-Host "❌ terraform.tfvars not found" -ForegroundColor Red
        Write-Host "Copy terraform.tfvars.example to terraform.tfvars and update values" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "✓ terraform.tfvars found" -ForegroundColor Green
    }
}

function Start-InfrastructureDeployment {
    Write-Banner "Deploying Infrastructure"
    
    # Initialize Terraform
    Write-Host "Initializing Terraform..." -ForegroundColor Yellow
    terraform init
    if ($LASTEXITCODE -ne 0) { exit 1 }
    
    # Plan deployment
    Write-Host "Planning deployment..." -ForegroundColor Yellow
    if ($WebServerCount -ne 2) {
        terraform plan -var="web_server_count=$WebServerCount"
    } else {
        terraform plan
    }
    if ($LASTEXITCODE -ne 0) { exit 1 }
    
    # Apply deployment
    Write-Host "Applying deployment..." -ForegroundColor Yellow
    if ($AutoApprove) {
        if ($WebServerCount -ne 2) {
            terraform apply -var="web_server_count=$WebServerCount" -auto-approve
        } else {
            terraform apply -auto-approve
        }
    } else {
        if ($WebServerCount -ne 2) {
            terraform apply -var="web_server_count=$WebServerCount"
        } else {
            terraform apply
        }
    }
    if ($LASTEXITCODE -ne 0) { exit 1 }
    
    # Show outputs
    Write-Banner "Deployment Complete"
    terraform output
    
    # Run Ansible configuration
    Write-Banner "Configuring Servers with Ansible"
    Start-AnsibleConfiguration
}

function Start-AnsibleConfiguration {
    Write-Host "Configuring servers with Ansible..." -ForegroundColor Yellow
    
    # Check if inventory file exists
    if (-not (Test-Path "ansible/inventory.ini")) {
        Write-Host "❌ Ansible inventory file not found" -ForegroundColor Red
        Write-Host "Please ensure Terraform completed successfully" -ForegroundColor Yellow
        return
    }
    
    # Test connectivity first
    Write-Host "Testing SSH connectivity..." -ForegroundColor Yellow
    Set-Location ansible
    
    # Wait for servers to be ready
    Write-Host "Waiting for servers to be ready..." -ForegroundColor Yellow
    Start-Sleep 30
    
    # Test connectivity
    $connectivityTest = ansible all -i inventory.ini -m ping --one-line 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ All servers are reachable" -ForegroundColor Green
        
        # Run the playbook
        Write-Host "Running Ansible playbook..." -ForegroundColor Yellow
        ansible-playbook -i inventory.ini playbook.yml
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Ansible configuration completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "❌ Ansible configuration failed" -ForegroundColor Red
            Write-Host "You can retry with: cd ansible && ansible-playbook -i inventory.ini playbook.yml" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Some servers are not reachable" -ForegroundColor Red
        Write-Host "Output: $connectivityTest" -ForegroundColor Yellow
        Write-Host "You can retry later with: cd ansible && ansible-playbook -i inventory.ini playbook.yml" -ForegroundColor Yellow
    }
    
    Set-Location ..
}

function Remove-Infrastructure {
    Write-Banner "Destroying Infrastructure"
    
    Write-Host "⚠️  This will destroy all infrastructure!" -ForegroundColor Red
    Write-Host "⚠️  All data will be lost!" -ForegroundColor Red
    
    if (-not $AutoApprove) {
        $confirm = Read-Host "Type 'yes' to confirm destruction"
        if ($confirm -ne "yes") {
            Write-Host "Destruction cancelled" -ForegroundColor Yellow
            exit 0
        }
    }
    
    terraform destroy -auto-approve
}

function Show-Status {
    Write-Banner "Infrastructure Status"
    
    # Check if terraform state exists
    if (-not (Test-Path ".terraform")) {
        Write-Host "❌ Terraform not initialized" -ForegroundColor Red
        Write-Host "Run: .\deploy.ps1 -Action deploy" -ForegroundColor Yellow
        exit 1
    }
    
    # Show terraform outputs
    Write-Host "Terraform Outputs:" -ForegroundColor Cyan
    terraform output
    
    # Test connectivity
    Write-Host "`nTesting Connectivity:" -ForegroundColor Cyan
    if (Test-Path "ansible/inventory.ini") {
        ansible all -i ansible/inventory.ini -m ping --one-line
    } else {
        Write-Host "❌ Ansible inventory not found" -ForegroundColor Red
    }
}

function Set-InfrastructureScale {
    param([int]$Count)
    
    Write-Banner "Scaling Infrastructure to $Count servers"
    
    terraform apply -var="web_server_count=$Count" -auto-approve
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully scaled to $Count servers" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to scale infrastructure" -ForegroundColor Red
        exit 1
    }
}

function Show-Help {
    Write-Host @"
Scalable Web Server Infrastructure Deployment Script

Usage: .\deploy.ps1 [options]

Actions:
  -Action deploy      Deploy the infrastructure (default)
  -Action destroy     Destroy the infrastructure
  -Action status      Show infrastructure status
  -Action scale       Scale web servers (use with -WebServerCount)

Options:
  -ProjectId <id>        GCP Project ID (optional if in tfvars)
  -WebServerCount <n>    Number of web servers (default: 2)
  -AutoApprove          Auto-approve terraform actions

Examples:
  .\deploy.ps1                                    # Deploy with defaults
  .\deploy.ps1 -Action deploy -AutoApprove        # Deploy without prompts
  .\deploy.ps1 -Action scale -WebServerCount 5    # Scale to 5 servers
  .\deploy.ps1 -Action status                     # Check status
  .\deploy.ps1 -Action destroy                    # Destroy infrastructure

Prerequisites:
  - Terraform installed
  - Ansible installed
  - gcloud CLI configured
  - SSH key at ~/.ssh/id_ed25519
  - terraform.tfvars file configured

"@ -ForegroundColor White
}

# Main execution
switch ($Action.ToLower()) {
    "deploy" {
        Test-Prerequisites
        Start-InfrastructureDeployment
    }
    "destroy" {
        Remove-Infrastructure
    }
    "status" {
        Show-Status
    }
    "scale" {
        Set-InfrastructureScale -Count $WebServerCount
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
