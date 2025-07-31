# Simple SSH-based server configuration
# This script uses direct SSH commands to configure the servers

$monitoringIP = "34.50.100.34"
$webServer1IP = "34.50.108.43"
$webServer2IP = "34.101.219.36"
$user = "53buahapel"
$keyPath = "~/.ssh/id_ed25519"

function Write-Banner {
    param([string]$Message)
    Write-Host "`n" + ("="*60) -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host ("="*60) -ForegroundColor Cyan
}

function Invoke-SSHCommand {
    param([string]$Server, [string]$Command, [switch]$Sudo = $false)
    
    if ($Sudo) {
        $Command = "sudo $Command"
    }
    
    Write-Host "Executing on ${Server}: $Command" -ForegroundColor Yellow
    ssh -i $keyPath -o StrictHostKeyChecking=no "$user@$Server" "$Command"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Success" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed" -ForegroundColor Red
    }
    return $LASTEXITCODE -eq 0
}

Write-Banner "Testing SSH Connectivity"

$servers = @($monitoringIP, $webServer1IP, $webServer2IP)
$reachableServers = @()

foreach ($server in $servers) {
    Write-Host "Testing connection to $server..." -ForegroundColor Yellow
    if (Invoke-SSHCommand -Server $server -Command "echo 'Connected successfully'") {
        $reachableServers += $server
        Write-Host "✓ $server is reachable" -ForegroundColor Green
    } else {
        Write-Host "❌ $server is not reachable" -ForegroundColor Red
    }
}

if ($reachableServers.Count -eq 0) {
    Write-Host "❌ No servers are reachable. Exiting." -ForegroundColor Red
    exit 1
}

Write-Banner "Installing Docker on All Servers"

foreach ($server in $reachableServers) {
    Write-Host "Installing Docker on $server..." -ForegroundColor Cyan
    
    # Update system
    Invoke-SSHCommand -Server $server -Command "apt-get update -y" -Sudo
    
    # Install prerequisites
    Invoke-SSHCommand -Server $server -Command "apt-get install -y curl wget git htop vim unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release" -Sudo
    
    # Add Docker GPG key and repository
    Invoke-SSHCommand -Server $server -Command "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
    Invoke-SSHCommand -Server $server -Command "echo 'deb [arch=`$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian `$(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
    
    # Install Docker
    Invoke-SSHCommand -Server $server -Command "apt-get update -y" -Sudo
    Invoke-SSHCommand -Server $server -Command "apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" -Sudo
    
    # Add user to docker group and start Docker
    Invoke-SSHCommand -Server $server -Command "usermod -aG docker $user" -Sudo
    Invoke-SSHCommand -Server $server -Command "systemctl start docker" -Sudo
    Invoke-SSHCommand -Server $server -Command "systemctl enable docker" -Sudo
    
    Write-Host "✓ Docker installation completed on $server" -ForegroundColor Green
}

Write-Banner "Configuring Monitoring Server"

if ($monitoringIP -in $reachableServers) {
    Write-Host "Setting up monitoring stack on $monitoringIP..." -ForegroundColor Cyan
    
    # Create directories
    Invoke-SSHCommand -Server $monitoringIP -Command "mkdir -p /opt/monitoring/prometheus /opt/monitoring/grafana /opt/monitoring/nginx" -Sudo
    Invoke-SSHCommand -Server $monitoringIP -Command "chown -R $user`:$user /opt/monitoring" -Sudo
    
    # Create Prometheus config file
    $prometheusConfig = @"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['10.1.0.4:9100', '10.1.0.5:9100']
  
  - job_name: 'web-servers'
    static_configs:
      - targets: ['10.1.0.4:3000', '10.1.0.5:3000']
"@
    
    # Write Prometheus config
    $prometheusConfig | ssh -i $keyPath -o StrictHostKeyChecking=no "$user@$monitoringIP" "cat > /opt/monitoring/prometheus/prometheus.yml"
    
    # Create Nginx config
    $nginxConfig = @"
upstream web_servers {
    server 10.1.0.4:3000;
    server 10.1.0.5:3000;
}

server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://web_servers;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }
    
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
"@
    
    # Write Nginx config
    $nginxConfig | ssh -i $keyPath -o StrictHostKeyChecking=no "$user@$monitoringIP" "cat > /opt/monitoring/nginx/default.conf"
    
    # Create Docker Compose
    $dockerCompose = @"
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped
  
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana-storage:/var/lib/grafana
    restart: unless-stopped
  
  nginx:
    image: nginx:alpine
    container_name: nginx-lb
    ports:
      - "80:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    restart: unless-stopped
    depends_on:
      - prometheus

volumes:
  grafana-storage:
"@
    
    # Write Docker Compose file
    $dockerCompose | ssh -i $keyPath -o StrictHostKeyChecking=no "$user@$monitoringIP" "cat > /opt/monitoring/docker-compose.yml"
    
    # Start monitoring stack
    Invoke-SSHCommand -Server $monitoringIP -Command "cd /opt/monitoring && docker compose up -d"
    
    Write-Host "✓ Monitoring server configured successfully" -ForegroundColor Green
}

Write-Banner "Configuring Web Servers"

foreach ($server in @($webServer1IP, $webServer2IP)) {
    if ($server -in $reachableServers) {
        Write-Host "Configuring web server $server..." -ForegroundColor Cyan
        
        # Create directories
        Invoke-SSHCommand -Server $server -Command "mkdir -p /opt/apps/web" -Sudo
        Invoke-SSHCommand -Server $server -Command "chown -R $user`:$user /opt/apps" -Sudo
        
        # Create Node.js app
        $appJs = @"
const express = require('express');
const app = express();
const port = 3000;
const os = require('os');

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Web Server!',
    hostname: os.hostname(),
    uptime: os.uptime(),
    loadavg: os.loadavg(),
    freemem: os.freemem(),
    totalmem: os.totalmem(),
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(\`
# HELP nodejs_heap_used_bytes Node.js heap used bytes
# TYPE nodejs_heap_used_bytes gauge
nodejs_heap_used_bytes \${process.memoryUsage().heapUsed}

# HELP nodejs_heap_total_bytes Node.js heap total bytes  
# TYPE nodejs_heap_total_bytes gauge
nodejs_heap_total_bytes \${process.memoryUsage().heapTotal}

# HELP nodejs_uptime_seconds Node.js uptime in seconds
# TYPE nodejs_uptime_seconds counter
nodejs_uptime_seconds \${process.uptime()}
  \`.trim());
});

app.listen(port, '0.0.0.0', () => {
  console.log(\`Web server running on port \${port}\`);
});
"@
        
        # Write app.js
        $appJs | ssh -i $keyPath -o StrictHostKeyChecking=no "$user@$server" "cat > /opt/apps/web/app.js"
        
        # Create package.json
        $packageJson = @"
{
  "name": "scalable-web-app",
  "version": "1.0.0",
  "description": "Scalable web application with monitoring",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
"@
        
        # Write package.json
        $packageJson | ssh -i $keyPath -o StrictHostKeyChecking=no "$user@$server" "cat > /opt/apps/web/package.json"
        
        # Create Dockerfile
        $dockerfile = @"
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

USER node

CMD ["npm", "start"]
"@
        
        # Write Dockerfile
        $dockerfile | ssh -i $keyPath -o StrictHostKeyChecking=no "$user@$server" "cat > /opt/apps/web/Dockerfile"
        
        # Create Docker Compose
        $dockerCompose = @"
version: '3.8'

services:
  web-app:
    build: .
    container_name: web-app
    ports:
      - "3000:3000"
    restart: unless-stopped
    environment:
      - NODE_ENV=production
  
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    restart: unless-stopped
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(`$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
"@
        
        # Write Docker Compose file
        $dockerCompose | ssh -i $keyPath -o StrictHostKeyChecking=no "$user@$server" "cat > /opt/apps/web/docker-compose.yml"
        
        # Build and start services
        Invoke-SSHCommand -Server $server -Command "cd /opt/apps/web && docker compose up -d --build"
        
        Write-Host "✓ Web server $server configured successfully" -ForegroundColor Green
    }
}

Write-Banner "Configuration Complete!"

Write-Host "🎉 All servers have been configured successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Access your services:" -ForegroundColor Cyan
Write-Host "- Load Balancer: http://$monitoringIP" -ForegroundColor White
Write-Host "- Grafana: http://$monitoringIP`:3000 (admin/admin123)" -ForegroundColor White
Write-Host "- Prometheus: http://$monitoringIP`:9090" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Access Grafana and import Node Exporter dashboard (ID: 1860)" -ForegroundColor White
Write-Host "2. Test the load balancer by refreshing the main URL" -ForegroundColor White
Write-Host "3. Check Prometheus targets at /targets" -ForegroundColor White
