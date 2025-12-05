#!/bin/bash

# Script to create Jenkins credentials as Kubernetes Secrets
# This is more secure than storing them in values.yaml

set -e

echo "🔐 Setting up Jenkins Credentials as Kubernetes Secrets"
echo "========================================================"
echo ""

# Check if namespace exists
if ! kubectl get namespace jenkins &> /dev/null; then
    echo "Creating jenkins namespace..."
    kubectl create namespace jenkins
fi

# Get ECR password
echo "📦 Getting AWS ECR password..."
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)
if [ -z "$ECR_PASSWORD" ]; then
    echo "❌ Failed to get ECR password. Make sure AWS CLI is configured."
    exit 1
fi
echo "✅ ECR password retrieved"

# Prompt for GitHub token
echo ""
echo "🔑 GitHub Personal Access Token Setup"
echo "-------------------------------------"

# Check if token is already saved
TOKEN_FILE="$HOME/.jenkins-github-token"
if [ -f "$TOKEN_FILE" ]; then
    echo "✅ Found saved GitHub token"
    GITHUB_TOKEN=$(cat "$TOKEN_FILE")
    read -p "Use saved token? (y/n): " use_saved
    if [ "$use_saved" != "y" ]; then
        GITHUB_TOKEN=""
    fi
fi

# Prompt for new token if not using saved one
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Please create a token at: https://github.com/settings/tokens?type=beta"
    echo ""
    echo "Required permissions:"
    echo "  - Repository access: All repositories (test-booking-application)"
    echo "  - Contents: Read-only"
    echo "  - Metadata: Read-only"
    echo "  - Webhooks: Read and write"
    echo ""
    read -sp "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
    echo ""
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "❌ GitHub token cannot be empty"
        exit 1
    fi
    
    # Save token for future use
    echo "$GITHUB_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo "💾 Token saved to $TOKEN_FILE (only you can read it)"
fi

# Create or update the secret
echo ""
echo "📝 Creating Kubernetes secret..."

kubectl create secret generic jenkins-credentials -n jenkins \
  --from-literal=github-token="$GITHUB_TOKEN" \
  --from-literal=ecr-password="$ECR_PASSWORD" \
  --from-literal=sonar-token="70c0a3a88c94b8692029efb356c3ca49911aef9b" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Docker Hub credentials
echo ""
echo "🐳 Setting up Docker Hub credentials..."
kubectl create secret generic dockerhub-creds -n jenkins \
  --from-literal=username="dilipnigam007" \
  --from-literal=password="zaq1xsw2" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ Secrets created successfully!"
echo ""
echo "📋 Summary:"
echo "  - jenkins-credentials secret:"
echo "    - Keys: github-token, ecr-password, sonar-token"
echo "  - dockerhub-creds secret:"
echo "    - Keys: username, password"
echo "  - Namespace: jenkins"
echo ""
echo "🚀 You can now deploy Jenkins with:"
echo "   cd tools/cicd/jenkins"
echo "   helm upgrade --install jenkins . -n jenkins -f values.yaml"
echo ""
echo "⚠️  Note: ECR password expires every 12 hours."
echo "   Re-run this script to refresh it."
