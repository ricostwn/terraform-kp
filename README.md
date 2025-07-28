# Terraform + Ansible Integration Guide

## Prerequisites

1. **Install Ansible on your local machine**:
   ```powershell
   # On Windows, use WSL or install via pip
   pip install ansible
   ```

2. **Ensure SSH access**:
   - Your SSH public key should be in your GCP project metadata
   - Private key should be at `~/.ssh/id_ed25519`

## Method 1: Manual (Recommended for learning)

### Step 1: Deploy infrastructure
```powershell
terraform init
terraform plan
terraform apply
```

### Step 2: Get the instance IP
```powershell
terraform output instance_ip
```

### Step 3: Update Ansible inventory
Edit `ansible/inventory.ini` and replace `YOUR_INSTANCE_IP` with the actual IP from step 2.

### Step 4: Test connectivity
```powershell
cd ansible
ansible monitoring_server -m ping
```

### Step 5: Run the playbook
```powershell
ansible-playbook setup.yml
```

## Method 2: Automatic (Using Terraform provisioner)

Just run:
```powershell
terraform apply
```

Terraform will automatically run Ansible after creating the instance.

## What gets installed:

✅ **System Updates**: Latest packages  
✅ **Essential Tools**: curl, wget, git, htop, vim  
✅ **Docker**: Latest version with docker-compose  
✅ **Node.js**: LTS version  
✅ **Python**: pip and virtualenv  
✅ **Monitoring**: htop, iotop, nmon, sysstat  
✅ **App Directory**: `/opt/apps` for your applications  

## Troubleshooting

### SSH Connection Issues:
```powershell
# Test manual SSH connection
ssh -i ~/.ssh/id_ed25519 53buahapel@<INSTANCE_IP>
```

### Ansible Connection Test:
```powershell
cd ansible
ansible monitoring_server -m ping -v
```

### Check what's installed:
```powershell
ansible monitoring_server -m shell -a "docker --version"
ansible monitoring_server -m shell -a "node --version"
```

## Next Steps

After the setup is complete, you can:
1. Deploy your applications to `/opt/apps`
2. Use Docker containers for services
3. Set up monitoring dashboards
4. Configure additional services as needed

## Example: Deploy a simple web app
```powershell
ansible monitoring_server -m shell -a "cd /opt/apps && git clone https://github.com/your-repo/your-app.git"
```
