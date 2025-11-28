# Infrastructure Tools - Helm Charts

Separate Helm charts for deploying infrastructure tools to Kubernetes/EKS.

## 📦 Tools Structure

```
tools/
├── monitoring/
│   ├── prometheus/          # Metrics collection
│   ├── grafana/             # Visualization dashboards
│   └── alertmanager/        # Alert management
├── logging/
│   ├── elasticsearch/       # Log storage
│   ├── kibana/              # Log visualization
│   └── filebeat/            # Log collection
└── ingress/
    └── nginx-ingress/       # Ingress controller
```

## 🚀 Quick Start

Deploy all monitoring tools:
```bash
./deploy-all.sh
```

## 📋 Individual Deployment

### Monitoring Stack

#### 1. Prometheus
```bash
cd monitoring/prometheus
helm dependency update
helm install prometheus . -n monitoring --create-namespace -f values.yaml
```

#### 2. Grafana
```bash
cd monitoring/grafana
helm dependency update
helm install grafana . -n monitoring --create-namespace -f values.yaml
```

Access Grafana:
- Get LoadBalancer URL: `kubectl get svc -n monitoring`
- **Username:** admin
- **Password:** admin

#### 3. Alertmanager
```bash
cd monitoring/alertmanager
helm dependency update
helm install alertmanager . -n monitoring --create-namespace -f values.yaml
```

### Logging Stack (ELK)

⚠️ **Warning:** Requires significant resources (t3.large+ nodes)

#### 1. Elasticsearch
```bash
cd logging/elasticsearch
helm dependency update
helm install elasticsearch . -n logging --create-namespace -f values.yaml
```

#### 2. Kibana
```bash
cd logging/kibana
helm dependency update
helm install kibana . -n logging --create-namespace -f values.yaml
```

Access Kibana:
- Get LoadBalancer URL: `kubectl get svc -n logging`
- Open `http://<LOADBALANCER-URL>:5601`

#### 3. Filebeat
```bash
cd logging/filebeat
helm dependency update
helm install filebeat . -n logging --create-namespace -f values.yaml
```

### Ingress Controller

```bash
cd ingress/nginx-ingress
helm dependency update
helm install nginx-ingress . -n ingress-nginx --create-namespace -f values.yaml
```

## 🛠 Customization

Each tool has its own `values.yaml` for customization:
- Resource limits
- Storage sizes
- Service types
- Feature flags

Edit the values file before deployment.

## 🗑️ Cleanup

Remove all tools:
```bash
./cleanup-all.sh
```

Or remove individually:
```bash
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring
helm uninstall alertmanager -n monitoring
helm uninstall elasticsearch -n logging
helm uninstall kibana -n logging
helm uninstall filebeat -n logging
helm uninstall nginx-ingress -n ingress-nginx
```

## 📊 Resource Requirements

| Tool | Min CPU | Min Memory | Storage |
|------|---------|------------|---------|
| Prometheus | 500m | 1Gi | 20Gi |
| Grafana | 250m | 512Mi | 10Gi |
| Alertmanager | 100m | 128Mi | 5Gi |
| Elasticsearch | 1000m | 2Gi | 30Gi |
| Kibana | 500m | 1Gi | - |
| Filebeat | 100m | 100Mi | - |
| Nginx Ingress | 100m | 90Mi | - |

**Recommended Node Type:**
- Monitoring only: t3.medium (2 vCPU, 4GB RAM)
- Monitoring + ELK: t3.large or m5.large (2 vCPU, 8GB RAM)

## 🔗 Integration

- **Grafana** auto-configured to use Prometheus as datasource
- **Kibana** auto-configured to connect to Elasticsearch
- **Filebeat** ships logs to Elasticsearch automatically
