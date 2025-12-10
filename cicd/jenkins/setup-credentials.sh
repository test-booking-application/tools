#!/bin/bash

# Script to setup ALL credentials and SSL certificates for the project
# Handles:
# 1. AWS ACM Certificates (Import/Reuse)
# 2. Updating values.yaml with Cert ARNs
# 3. Jenkins Kubernetes Secrets (GitHub, ECR, DockerHub)

set -e

# Find repo root (assuming script is in tools/cicd/jenkins)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CERT_DIR="$SCRIPT_DIR/certs"
REGION="us-east-1"

echo "🚀 Starting Full Setup (SSL + Credentials)"
echo "=========================================="
echo "Repo Root: $REPO_ROOT"
echo ""

# Function to get or import certificate
get_or_import_cert() {
    DOMAIN=$1
    SERVICE_NAME=$2
    LOCAL_CERT_PATH="$CERT_DIR/$SERVICE_NAME"
    
    echo "🔍 Checking SSL Cert for $DOMAIN..."

    # Check if cert exists in ACM
    EXISTING_ARN=$(aws acm list-certificates --region $REGION --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text)

    if [ -n "$EXISTING_ARN" ]; then
        echo "✅ Found existing AWS ACM certificate: $EXISTING_ARN"
        CERT_ARN=$EXISTING_ARN
    else
        echo "⚠️  No certificate found in AWS. Importing from local files..."
        
        if [ ! -f "$LOCAL_CERT_PATH/cert.pem" ]; then
            echo "❌ Error: Local certificate files not found in $LOCAL_CERT_PATH/"
            echo "   Please ensure you have generated certs with Certbot and copied them there."
            echo "   Command to fix: sudo cp /etc/letsencrypt/live/.../*.pem $REPO_ROOT/certs/$SERVICE_NAME/"
            exit 1
        fi

        # Import cert
        CERT_ARN=$(aws acm import-certificate \
            --certificate fileb://"$LOCAL_CERT_PATH/cert.pem" \
            --private-key fileb://"$LOCAL_CERT_PATH/privkey.pem" \
            --certificate-chain fileb://"$LOCAL_CERT_PATH/chain.pem" \
            --region $REGION \
            --output text --query CertificateArn)
            
        echo "✅ Successfully imported certificate. New ARN: $CERT_ARN"
    fi
}

# --- 1. SSL Setup ---

# Function to update values.yaml with ARNs
update_values_file() {
    FILE=$1
    CERT_ARN=$2
    
    echo "📄 Updating $FILE..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # Mac sed
      sed -i '' "s|alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: \"$CERT_ARN\"|g" "$FILE"
    else
      # Linux sed
      sed -i "s|alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: \"$CERT_ARN\"|g" "$FILE"
    fi
}

# ArgoCD Setup
get_or_import_cert "argocd007.duckdns.org" "argocd"
update_values_file "$REPO_ROOT/argocd/values.yaml" "$CERT_ARN"

# Jenkins Setup
get_or_import_cert "jenkins007.duckdns.org" "jenkins"
update_values_file "$REPO_ROOT/tools/cicd/jenkins/values.yaml" "$CERT_ARN"

# Frontend Setup
get_or_import_cert "ticketbooking.duckdns.org" "frontend"
update_values_file "$REPO_ROOT/frontend/charts/frontend/values.yaml" "$CERT_ARN"

echo "📝 All values.yaml files updated!"
echo ""

# --- 2. Kubernetes Secrets Setup ---
echo "🔐 Setting up Jenkins Secrets..."


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
