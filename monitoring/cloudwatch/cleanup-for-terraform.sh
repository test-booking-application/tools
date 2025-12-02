#!/bin/bash
set -e

CLUSTER_NAME="ticket-booking-eks"
REGION="us-east-1"

echo "🧹 Cleaning up CloudWatch resources to allow Terraform to take over..."

# 1. Delete EKS Add-on
echo "1️⃣  Deleting EKS Add-on: amazon-cloudwatch-observability..."
aws eks delete-addon \
  --cluster-name $CLUSTER_NAME \
  --addon-name amazon-cloudwatch-observability \
  --region $REGION \
  --preserve \
  || echo "⚠️  Add-on not found or already deleted"

# Wait for add-on deletion
echo "⏳ Waiting for add-on deletion..."
aws eks wait addon-deleted \
  --cluster-name $CLUSTER_NAME \
  --addon-name amazon-cloudwatch-observability \
  --region $REGION \
  || echo "⚠️  Wait timed out or add-on already gone"

# 2. Delete CloudWatch Log Groups
LOG_GROUPS=(
  "/aws/containerinsights/$CLUSTER_NAME/application"
  "/aws/containerinsights/$CLUSTER_NAME/host"
  "/aws/containerinsights/$CLUSTER_NAME/dataplane"
)

echo "2️⃣  Deleting CloudWatch Log Groups..."
for group in "${LOG_GROUPS[@]}"; do
  echo "   - Deleting $group..."
  aws logs delete-log-group --log-group-name "$group" --region $REGION || echo "⚠️  Log group $group not found or already deleted"
done

echo "✅ Cleanup complete!"
echo "🚀 You can now run the Terraform pipeline in GitHub Actions."
