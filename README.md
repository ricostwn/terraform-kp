# Scalable Web Server Infrastructure with Monitoring

This project creates a scalable web server infrastructure on Google Cloud Platform using Terraform and Ansible. The infrastructure includes:

- **Monitoring Server**: Nginx Load Balancer + Prometheus + Grafana
- **Web Server Cluster**: Dockerized Node.js applications with Node Exporter
- **Auto-scaling**: PowerShell script for automatic horizontal scaling based on metrics

## Architecture Overview

```
Internet
    ↓
Monitoring Server (Static IP)
├── Nginx Load Balancer (:80)
├── Prometheus (:9090)
└── Grafana (:3000)
    ↓
Web Server Cluster
├── Web Server 1 (Docker + Node Exporter)
├── Web Server 2 (Docker + Node Exporter)
└── Web Server N (Auto-scalable)
```

## Prerequisites

1. **Google Cloud Platform Account**
   - Project with billing enabled
   - Service account with appropriate permissions
   - `gcloud` CLI configured

2. **Local Tools**
   - Terraform >= 1.0
   - Ansible >= 2.9
   - SSH key pair (Ed25519 recommended)
   - PowerShell (for auto-scaling script)

3. **SSH Setup**
   - Generate SSH key: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519`
   - Add public key to GCP metadata or use in terraform variables

## Quick Start

### 1. Configure Variables

Create `terraform.tfvars` file:

```hcl
project_id = "your-gcp-project-id"
region = "asia-southeast2"
web_server_count = 2
ssh_user = "your-username"
ssh_key_path = "~/.ssh/id_ed25519"
```

### 2. Deploy Infrastructure

```powershell
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

### 3. Access Services

After deployment, access these services:

- **Load Balancer**: `http://<monitoring-server-ip>`
- **Grafana**: `http://<monitoring-server-ip>:3000` (admin/admin123)
- **Prometheus**: `http://<monitoring-server-ip>:9090`

## Infrastructure Components

### Monitoring Server
- **Nginx Load Balancer**: Distributes traffic across web servers
- **Prometheus**: Collects metrics from all servers
- **Grafana**: Visualizes metrics and creates dashboards

### Web Servers
- **Node.js Application**: Sample web app with health checks and metrics
- **Node Exporter**: System metrics collection
- **Docker**: Containerized applications

## Auto-Scaling

The project includes an automatic scaling script that monitors CPU usage and scales web servers:

### Manual Scaling
```powershell
# Scale to 3 servers
terraform apply -var="web_server_count=3"
```

### Automatic Scaling
```powershell
# Start auto-scaling monitoring
.\auto-scale.ps1
```

**Scaling Thresholds:**
- Scale Up: CPU > 70%
- Scale Down: CPU < 30%
- Min Servers: 2
- Max Servers: 5

## Monitoring Setup

### Grafana Dashboards

1. **Import Node Exporter Dashboard**:
   - Go to Grafana → Import Dashboard
   - Use dashboard ID: `1860`
   - Select Prometheus data source

2. **Custom Application Dashboard**:
   - Monitor application metrics at `/metrics` endpoint
   - Track response times, request counts, memory usage

### Prometheus Targets

- **Node Exporters**: Monitor system metrics
- **Web Applications**: Monitor application metrics
- **Prometheus Self**: Monitor Prometheus itself

## File Structure

```
terraform/
├── main.tf                 # Provider configuration
├── variables.tf            # Input variables
├── vpc.tf                  # Network configuration
├── firewall.tf             # Security rules
├── instances.tf            # VM instances
├── outputs.tf              # Output values
├── terraform.tfvars        # Variable values (create this)
├── auto-scale.ps1          # Auto-scaling script
├── auto-scale.sh           # Auto-scaling script (bash)
└── ansible/
    ├── inventory.tpl       # Ansible inventory template
    ├── inventory.ini       # Generated inventory
    ├── ansible.cfg         # Ansible configuration
    ├── playbook.yml        # Main playbook
    └── setup.yml           # Legacy setup playbook
```

## Firewall Rules

The infrastructure creates these firewall rules:

- **SSH (22)**: Admin access
- **HTTP (80)**: Load balancer access
- **HTTPS (443)**: Secure web access
- **Grafana (3000)**: Dashboard access
- **Prometheus (9090)**: Metrics access
- **Node Exporter (9100)**: Internal metrics collection
- **Application (3000, 8080, 8000)**: Internal app communication

## Customization

### Modify Web Application

Edit the Node.js application in the Ansible playbook:
- Change `app.js` content
- Add dependencies to `package.json`
- Modify Dockerfile for different runtime

### Add More Monitoring

1. **Add Custom Metrics**:
   ```javascript
   app.get('/metrics', (req, res) => {
     // Add custom metrics here
   });
   ```

2. **Configure Alerts**:
   - Add alerting rules to Prometheus
   - Configure notification channels in Grafana

### Scale Configuration

Modify scaling parameters in `auto-scale.ps1`:
- Threshold values
- Min/max server counts
- Check intervals

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**:
   - Verify SSH key path and permissions
   - Check firewall rules allow SSH (port 22)
   - Ensure public key is in GCP metadata

2. **Ansible Connection Failed**:
   - Wait for instances to fully boot
   - Check inventory.ini file generation
   - Verify SSH connectivity

3. **Services Not Starting**:
   - Check Docker daemon status
   - Verify firewall rules
   - Check application logs: `docker logs <container>`

### Debugging Commands

```powershell
# Check Terraform state
terraform show

# Verify Ansible connectivity
ansible all -i ansible/inventory.ini -m ping

# Check service status on servers
ansible all -i ansible/inventory.ini -a "docker ps"

# View application logs
ssh user@server-ip "docker logs web-app"
```

## Security Considerations

1. **SSH Keys**: Use strong key pairs and rotate regularly
2. **Firewall Rules**: Restrict access to necessary ports only
3. **Credentials**: Change default Grafana password
4. **Updates**: Keep system packages and Docker images updated
5. **Monitoring**: Set up alerts for security events

## Cost Optimization

1. **Instance Types**: Use appropriate machine types for workload
2. **Auto-scaling**: Prevents over-provisioning
3. **Preemptible Instances**: Consider for non-critical workloads
4. **Storage**: Optimize disk sizes
5. **Monitoring**: Track resource usage and optimize

## Next Steps

1. **SSL/TLS**: Add HTTPS termination to load balancer
2. **Database**: Add managed database (Cloud SQL)
3. **CI/CD**: Integrate with deployment pipelines
4. **Backup**: Implement backup strategies
5. **Multi-region**: Deploy across multiple regions
6. **Service Mesh**: Consider Istio for advanced traffic management

## Support

For issues or questions:
1. Check logs in Grafana and Prometheus
2. Review Terraform state and outputs
3. Verify Ansible playbook execution
4. Check GCP console for resource status

---

**Note**: This infrastructure is designed for development and testing. For production use, implement additional security, monitoring, and backup strategies.
