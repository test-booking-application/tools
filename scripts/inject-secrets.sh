#!/bin/bash
set -e

echo "🔐 Injecting Secrets into EKS Cluster..."

# Check required environment variables
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN is not set"
    exit 1
fi

if [ -z "$SONAR_TOKEN" ]; then
    echo "⚠️ Warning: SONAR_TOKEN is not set, using placeholder"
    SONAR_TOKEN="placeholder-token"
fi

# Ensure kubectl is configured
if ! kubectl get nodes &> /dev/null; then
    echo "❌ Error: kubectl is not configured or cannot connect to the cluster"
    exit 1
fi

# Create jenkins namespace if it doesn't exist
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Get ECR Password
echo "📦 Getting AWS ECR password..."
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)

if [ -z "$ECR_PASSWORD" ]; then
    echo "❌ Error: Failed to get ECR password"
    exit 1
fi

# Create the secret
echo "📝 Creating/Updating 'jenkins-credentials' secret in 'jenkins' namespace..."
kubectl create secret generic jenkins-credentials -n jenkins \
  --from-literal=github-token="$GITHUB_TOKEN" \
  --from-literal=ecr-password="$ECR_PASSWORD" \
  --from-literal=sonar-token="$SONAR_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets injected successfully!"
