Write-Host "🚀 Starting Automatic Infrastructure + Software Deployment..." -ForegroundColor Green
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  ✅ Create GCP VM instance" -ForegroundColor Cyan
Write-Host "  ✅ Install Docker, Node.js, Python" -ForegroundColor Cyan
Write-Host "  ✅ Setup monitoring tools" -ForegroundColor Cyan
Write-Host "  ✅ Configure the server automatically" -ForegroundColor Cyan
Write-Host ""

# Check if Ansible is installed
try {
    ansible --version | Out-Null
    Write-Host "✅ Ansible is installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Ansible is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "   pip install ansible" -ForegroundColor Yellow
    exit 1
}

# Check if SSH key exists
if (Test-Path "~/.ssh/id_ed25519") {
    Write-Host "✅ SSH private key found" -ForegroundColor Green
} else {
    Write-Host "❌ SSH private key not found at ~/.ssh/id_ed25519" -ForegroundColor Red
    Write-Host "   Please ensure your SSH key is properly configured" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🚀 Starting deployment..." -ForegroundColor Green

# Initialize and apply Terraform
terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform init failed" -ForegroundColor Red
    exit 1
}

terraform plan
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform plan failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎯 Applying Terraform configuration (this will also run Ansible automatically)..." -ForegroundColor Yellow

terraform apply -auto-approve
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 SUCCESS! Your infrastructure is deployed and configured!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Instance Details:" -ForegroundColor Cyan
terraform output

Write-Host ""
Write-Host "🔗 Next steps:" -ForegroundColor Yellow
Write-Host "  1. SSH to your instance: ssh -i ~/.ssh/id_ed25519 53buahapel@$(terraform output -raw instance_ip)" -ForegroundColor White
Write-Host "  2. Check Docker: docker --version" -ForegroundColor White  
Write-Host "  3. Check Node.js: node --version" -ForegroundColor White
Write-Host "  4. Deploy your apps to: /opt/apps" -ForegroundColor White
