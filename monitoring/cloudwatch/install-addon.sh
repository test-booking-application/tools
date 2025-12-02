#!/bin/bash

set -e

echo "☁️  Installing CloudWatch Container Insights via EKS Add-on"
echo "=========================================================="
echo ""
echo "This is the AWS recommended method for production environments."
echo ""

# Variables
CLUSTER_NAME="ticket-booking-eks"
REGION="us-east-1"
ADDON_NAME="amazon-cloudwatch-observability"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📋 AWS Account: $ACCOUNT_ID"
echo "📋 Cluster: $CLUSTER_NAME"
echo "📍 Region: $REGION"
echo ""

# Step 1: Create IAM policy for CloudWatch
echo "🔐 Step 1: Creating IAM policy for CloudWatch..."

POLICY_NAME="AmazonEKS_Observability_Policy"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

# Check if policy already exists
if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo "✓ Policy already exists: $POLICY_NAME"
else
    cat > /tmp/cloudwatch-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
                "cloudwatch:PutMetricData",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes"
            ],
            "Resource": "*"
        }
    ]
}
EOF

    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file:///tmp/cloudwatch-policy.json \
        --description "Policy for CloudWatch Container Insights on EKS"
    
    echo "✓ Created IAM policy: $POLICY_NAME"
    rm /tmp/cloudwatch-policy.json
fi

# Step 2: Create IAM role for service account (IRSA)
echo ""
echo "🔐 Step 2: Creating IAM role for service account..."

# Create OIDC provider if not exists
echo "Checking OIDC provider..."
if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.identity.oidc.issuer" --output text | grep -q "oidc.eks"; then
    echo "Creating OIDC provider..."
    eksctl utils associate-iam-oidc-provider \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION" \
        --approve
else
    echo "✓ OIDC provider already exists"
fi

# Create service account with IAM role
echo "Creating service account with IAM role..."
eksctl create iamserviceaccount \
    --name cloudwatch-agent \
    --namespace amazon-cloudwatch \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --attach-policy-arn "$POLICY_ARN" \
    --attach-policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
    --approve \
    --override-existing-serviceaccounts

echo "✓ Created service account with IAM role"

# Step 3: Install CloudWatch Observability Add-on
echo ""
echo "⚙️  Step 3: Installing CloudWatch Observability EKS Add-on..."

# Check if add-on already exists
if aws eks describe-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name "$ADDON_NAME" \
    --region "$REGION" &>/dev/null; then
    
    echo "Add-on already exists. Updating..."
    aws eks update-addon \
        --cluster-name "$CLUSTER_NAME" \
        --addon-name "$ADDON_NAME" \
        --region "$REGION" \
        --resolve-conflicts OVERWRITE
else
    echo "Installing add-on..."
    aws eks create-addon \
        --cluster-name "$CLUSTER_NAME" \
        --addon-name "$ADDON_NAME" \
        --region "$REGION"
fi

echo "✓ CloudWatch Observability add-on installed"

# Wait for add-on to be active
echo ""
echo "⏳ Waiting for add-on to become active..."
aws eks wait addon-active \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name "$ADDON_NAME" \
    --region "$REGION"

echo "✓ Add-on is active"

# Step 4: Verify installation
echo ""
echo "✅ Installation Complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check namespace
echo "Checking namespace..."
kubectl get namespace amazon-cloudwatch 2>/dev/null || echo "⚠️  Namespace not yet created (may take a moment)"

# Check pods
echo ""
echo "Checking pods (may take 1-2 minutes to start)..."
kubectl get pods -n amazon-cloudwatch 2>/dev/null || echo "⚠️  Pods not yet created (may take a moment)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Access Your Data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Container Insights Dashboard:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#container-insights:infrastructure"
echo ""
echo "CloudWatch Logs:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups"
echo ""
echo "Log Groups:"
echo "  - /aws/containerinsights/${CLUSTER_NAME}/application"
echo "  - /aws/containerinsights/${CLUSTER_NAME}/host"
echo "  - /aws/containerinsights/${CLUSTER_NAME}/dataplane"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Tip: It may take 5-10 minutes for metrics to appear in CloudWatch"
