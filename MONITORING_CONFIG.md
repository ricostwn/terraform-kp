# Additional monitoring configurations and dashboards

## Prometheus Alerting Rules

Create `/opt/monitoring/prometheus/alerts.yml`:

```yaml
groups:
  - name: web_server_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes on {{ $labels.instance }}"
      
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 90% for more than 5 minutes on {{ $labels.instance }}"
      
      - alert: WebServerDown
        expr: up{job="web-servers"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Web server is down"
          description: "Web server {{ $labels.instance }} has been down for more than 1 minute"
      
      - alert: HighResponseTime
        expr: nodejs_uptime_seconds > 1000
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High response time on {{ $labels.instance }}"
          description: "Response time is consistently high on {{ $labels.instance }}"
```

## Grafana Dashboard JSON

Save this as a dashboard in Grafana for comprehensive monitoring:

```json
{
  "dashboard": {
    "id": null,
    "title": "Web Server Cluster Monitoring",
    "tags": ["web-server", "monitoring"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{ instance }}"
          }
        ],
        "yAxes": [
          {
            "label": "Percent",
            "max": 100,
            "min": 0
          }
        ]
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "{{ instance }}"
          }
        ]
      },
      {
        "id": 3,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(nodejs_uptime_seconds[5m])",
            "legendFormat": "{{ instance }}"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

## Custom Application Metrics

Add to your Node.js application for better monitoring:

```javascript
const prometheus = require('prom-client');

// Create custom metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new prometheus.Gauge({
  name: 'active_connections',
  help: 'Number of active connections'
});

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
    
    httpRequestTotal
      .labels(req.method, route, res.statusCode)
      .inc();
  });
  
  next();
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});
```

## Load Testing Script

Create `load-test.ps1` for testing auto-scaling:

```powershell
param(
    [string]$TargetUrl = "http://localhost",
    [int]$Requests = 1000,
    [int]$Concurrency = 10,
    [int]$Duration = 300
)

function Start-LoadTest {
    Write-Host "Starting load test against $TargetUrl" -ForegroundColor Cyan
    Write-Host "Requests: $Requests, Concurrency: $Concurrency, Duration: $Duration seconds" -ForegroundColor Yellow
    
    # Using curl for load testing (install if not available)
    1..$Requests | ForEach-Object -Parallel {
        $response = Invoke-WebRequest -Uri $using:TargetUrl -TimeoutSec 30 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "✓" -NoNewline -ForegroundColor Green
        } else {
            Write-Host "✗" -NoNewline -ForegroundColor Red
        }
    } -ThrottleLimit $Concurrency
    
    Write-Host "`nLoad test completed" -ForegroundColor Cyan
}

Start-LoadTest
```

## Health Check Script

Create `health-check.ps1` for monitoring:

```powershell
param(
    [string]$ConfigFile = "terraform.tfvars"
)

function Test-ServiceHealth {
    param([string]$Url, [string]$ServiceName)
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ $ServiceName is healthy" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠ $ServiceName returned status $($response.StatusCode)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "✗ $ServiceName is unreachable: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Get monitoring server IP from terraform output
$monitoringIp = terraform output -raw monitoring_server_ip

if (-not $monitoringIp) {
    Write-Host "❌ Could not get monitoring server IP" -ForegroundColor Red
    exit 1
}

Write-Host "Health Check Report" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

# Test services
$services = @{
    "Load Balancer" = "http://$monitoringIp"
    "Grafana" = "http://$monitoringIp:3000"
    "Prometheus" = "http://$monitoringIp:9090"
}

$healthyServices = 0
foreach ($service in $services.GetEnumerator()) {
    if (Test-ServiceHealth -Url $service.Value -ServiceName $service.Key) {
        $healthyServices++
    }
}

Write-Host "`nSummary: $healthyServices/$($services.Count) services are healthy" -ForegroundColor Cyan

if ($healthyServices -eq $services.Count) {
    Write-Host "🎉 All services are running properly!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️ Some services have issues" -ForegroundColor Yellow
    exit 1
}
```
