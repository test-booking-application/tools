# Monitoring Setup for ticket-booking-eks

## ✅ Installed: AWS CloudWatch Container Insights

**Status**: Active and Running  
**Method**: EKS Add-on (Production-ready)  
**Version**: v4.7.0-eksbuild.1

### Components Running

```
amazon-cloudwatch-observability-controller-manager  ✓ Running
cloudwatch-agent (2 pods - one per node)            ✓ Running  
fluent-bit (2 pods - one per node)                  ✓ Running
```

### What's Being Monitored

- ✅ Cluster metrics (CPU, memory, network, disk)
- ✅ Node metrics (per EC2 instance)
- ✅ Pod metrics (all pods across all namespaces)
- ✅ Container metrics (individual container performance)
- ✅ Application logs (all container stdout/stderr)
- ✅ Kubernetes events

### Access Your Data

#### Container Insights Dashboard
View real-time cluster performance:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#container-insights:infrastructure
```

#### CloudWatch Logs
View and query application logs:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups
```

**Log Groups Created:**
- `/aws/containerinsights/ticket-booking-eks/application` - Application logs
- `/aws/containerinsights/ticket-booking-eks/host` - Node/host logs
- `/aws/containerinsights/ticket-booking-eks/dataplane` - Kubernetes control plane logs

### Useful CloudWatch Insights Queries

#### Find Application Errors
```sql
fields @timestamp, kubernetes.pod_name, kubernetes.namespace_name, log
| filter log like /ERROR|error|Error|exception|Exception/
| sort @timestamp desc
| limit 100
```

#### Pod CPU Usage Over Time
```sql
fields @timestamp, PodName, pod_cpu_utilization_over_pod_limit
| filter Type = "Pod" and Namespace = "default"
| sort @timestamp desc
| limit 50
```

#### Memory Usage by Namespace
```sql
fields @timestamp, Namespace, pod_memory_utilization
| filter Type = "Pod"
| stats avg(pod_memory_utilization) as AvgMemory by Namespace
| sort AvgMemory desc
```

#### Failed Pod Events
```sql
fields @timestamp, kubernetes.pod_name, reason, message
| filter reason like /Failed|Error|BackOff/
| sort @timestamp desc
```

### Cost Estimation

**Current Setup (2-node cluster):**
- Metrics: ~500-1000 custom metrics = $0-150/month (first 10K free)
- Logs: ~5-10 GB/month = $2.50-5.00/month
- Storage: ~5 GB = $0.15/month

**Estimated Total**: $10-20/month

### Verification Commands

```bash
# Check add-on status
aws eks describe-addon \
  --cluster-name ticket-booking-eks \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1

# Check pods
kubectl get pods -n amazon-cloudwatch

# Check CloudWatch agent logs
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent --tail=50

# Check Fluent Bit logs
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=fluent-bit --tail=50
```

### Troubleshooting

#### No metrics appearing in CloudWatch
1. Wait 5-10 minutes for initial metrics to appear
2. Check CloudWatch agent logs:
   ```bash
   kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent
   ```
3. Verify IAM permissions are correct

#### Logs not appearing
1. Check Fluent Bit is running:
   ```bash
   kubectl get pods -n amazon-cloudwatch -l app.kubernetes.io/name=fluent-bit
   ```
2. Check Fluent Bit logs for errors:
   ```bash
   kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=fluent-bit
   ```

### Uninstall

```bash
# Remove the EKS add-on
aws eks delete-addon \
  --cluster-name ticket-booking-eks \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1

# Clean up namespace (optional)
kubectl delete namespace amazon-cloudwatch
```

### Next Steps

1. **Set up CloudWatch Alarms** for critical metrics:
   - High CPU usage (>80%)
   - High memory usage (>80%)
   - Pod restart count
   - Failed deployments

2. **Create Custom Dashboards** in CloudWatch for:
   - Application-specific metrics
   - Business KPIs
   - Service health overview

3. **Configure Log Retention**:
   - Default: Logs never expire
   - Recommended: 7-30 days for cost optimization

4. **Add Application Performance Monitoring (APM)**:
   - Consider adding New Relic (100 GB/month free) for deeper application insights
   - Or AWS X-Ray for distributed tracing

### Additional Monitoring Options

If you want more comprehensive monitoring, consider adding:

1. **New Relic** (Free 100 GB/month) - Better APM and application insights
2. **Grafana Cloud** (Free tier) - Better visualization and Prometheus metrics
3. **AWS X-Ray** - Distributed tracing for microservices

See `/tools/monitoring/newrelic/` and `/tools/monitoring/datadog/` for setup instructions.

---

**Installation Date**: 2025-12-02  
**Installed By**: Automated setup script  
**Documentation**: `/tools/monitoring/cloudwatch/README.md`
