# AWS CloudWatch Container Insights for EKS

Production-ready monitoring setup using AWS CloudWatch Container Insights.

## Architecture

This setup uses the **Amazon CloudWatch Observability EKS Add-on** (recommended by AWS for production):

- **CloudWatch Agent**: Collects metrics from cluster, nodes, pods, and containers
- **Fluent Bit**: Collects and forwards logs to CloudWatch Logs
- **IAM Roles for Service Accounts (IRSA)**: Secure, no static credentials
- **Container Insights**: Pre-built dashboards and metrics

## Prerequisites

- EKS cluster running (Kubernetes 1.23+)
- AWS CLI configured
- `kubectl` configured for your cluster
- IAM permissions to create policies and roles

## Installation Methods

### Method 1: EKS Add-on (Recommended for Production)

This is the **official AWS recommended method** for production environments.

```bash
cd /Users/dilipnigam/Downloads/antigravity_application/tools/monitoring/cloudwatch
chmod +x install-addon.sh
./install-addon.sh
```

### Method 2: Kubernetes Manifests (Manual Control)

For more granular control over the deployment.

```bash
cd /Users/dilipnigam/Downloads/antigravity_application/tools/monitoring/cloudwatch
chmod +x install-manifests.sh
./install-manifests.sh
```

## What Gets Monitored

- ✅ **Cluster-level metrics**: Overall cluster health and resource usage
- ✅ **Node metrics**: CPU, memory, disk, network per node
- ✅ **Pod metrics**: Resource usage per pod
- ✅ **Container metrics**: Individual container performance
- ✅ **Kubernetes events**: Cluster events and state changes
- ✅ **Application logs**: All container logs

## Accessing Data

### Container Insights Dashboard
1. Go to AWS Console → CloudWatch
2. Click "Container Insights" in left menu
3. Select "Performance monitoring"
4. Choose your cluster: `ticket-booking-eks`

### CloudWatch Logs
- Log Group: `/aws/containerinsights/ticket-booking-eks/application`
- Log Group: `/aws/containerinsights/ticket-booking-eks/host`
- Log Group: `/aws/containerinsights/ticket-booking-eks/dataplane`

### Useful CloudWatch Insights Queries

**Find errors in application logs:**
```
fields @timestamp, kubernetes.pod_name, log
| filter log like /ERROR|error|Error/
| sort @timestamp desc
| limit 100
```

**Pod CPU usage:**
```
fields @timestamp, PodName, pod_cpu_utilization_over_pod_limit
| filter Type = "Pod"
| sort @timestamp desc
```

**Memory usage by namespace:**
```
fields @timestamp, Namespace, pod_memory_utilization
| filter Type = "Pod"
| stats avg(pod_memory_utilization) by Namespace
```

## Cost Estimation

CloudWatch pricing (us-east-1):
- **Metrics**: First 10,000 metrics free, then $0.30/metric/month
- **Logs Ingestion**: $0.50 per GB
- **Logs Storage**: $0.03 per GB/month
- **Dashboards**: First 3 free, then $3/dashboard/month

**Estimated cost for small EKS cluster (2 nodes)**: $15-30/month

## Verification

Check if Container Insights is collecting data:

```bash
# Check if add-on is installed
aws eks describe-addon \
  --cluster-name ticket-booking-eks \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1

# Check pods
kubectl get pods -n amazon-cloudwatch

# Check logs
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent --tail=50
```

## Uninstall

### If using EKS Add-on:
```bash
aws eks delete-addon \
  --cluster-name ticket-booking-eks \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1
```

### If using manifests:
```bash
kubectl delete namespace amazon-cloudwatch
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n amazon-cloudwatch
kubectl logs -n amazon-cloudwatch <pod-name>
```

### No metrics appearing
- Check IAM permissions on node role
- Verify CloudWatch agent is running: `kubectl get pods -n amazon-cloudwatch`
- Check CloudWatch agent logs for errors

### High costs
- Reduce log retention period
- Filter logs before sending to CloudWatch
- Use metric filters to reduce custom metrics
