#!/bin/bash

# Script to automatically configure GitHub webhooks for all repositories
# This uses the GitHub CLI (gh) to update webhooks

set -e

echo "🔗 GitHub Webhook Configuration Script"
echo "======================================="
echo ""

# Configuration
JENKINS_URL="http://jenkins007.duckdns.org:8080/github-webhook/"
GITHUB_ORG="test-booking-application"
REPOS=("ticket-service" "user-service" "booking-service" "api-gateway" "frontend")

# Check if running in CI (GitHub Actions) or locally
if [ -n "$GITHUB_TOKEN" ]; then
    echo "✅ Running in CI/CD mode (using GITHUB_TOKEN)"
    USE_GH_CLI=false
else
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI (gh) is not installed."
        echo "   Install it from: https://cli.github.com/"
        echo "   Or run: brew install gh"
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        echo "❌ Not authenticated with GitHub CLI."
        echo "   Run: gh auth login"
        exit 1
    fi
    
    echo "✅ GitHub CLI is installed and authenticated"
    USE_GH_CLI=true
fi
echo ""

# Function to configure webhook for a repository
configure_webhook() {
    local repo=$1
    local full_repo="${GITHUB_ORG}/${repo}"
    
    echo "📦 Configuring webhook for ${full_repo}..."
    
    if [ "$USE_GH_CLI" = true ]; then
        # Use GitHub CLI
        EXISTING_WEBHOOK=$(gh api repos/${full_repo}/hooks --jq ".[] | select(.config.url == \"${JENKINS_URL}\") | .id" 2>/dev/null || echo "")
        
        if [ -n "$EXISTING_WEBHOOK" ]; then
            echo "   ⚠️  Webhook already exists (ID: ${EXISTING_WEBHOOK}). Updating..."
            gh api -X PATCH repos/${full_repo}/hooks/${EXISTING_WEBHOOK} \
                -f config[url]="${JENKINS_URL}" \
                -f config[content_type]="json" \
                -F active=true \
                -f events[]="push" \
                -f events[]="pull_request" > /dev/null
            echo "   ✅ Webhook updated!"
        else
            echo "   Creating new webhook..."
            gh api -X POST repos/${full_repo}/hooks \
                -f name="web" \
                -f config[url]="${JENKINS_URL}" \
                -f config[content_type]="json" \
                -F active=true \
                -f events[]="push" \
                -f events[]="pull_request" > /dev/null
            echo "   ✅ Webhook created!"
        fi
    else
        # Use curl with GITHUB_TOKEN (for CI/CD)
        EXISTING_WEBHOOK=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
            "https://api.github.com/repos/${full_repo}/hooks" | \
            jq -r ".[] | select(.config.url == \"${JENKINS_URL}\") | .id" || echo "")
        
        if [ -n "$EXISTING_WEBHOOK" ]; then
            echo "   ⚠️  Webhook already exists (ID: ${EXISTING_WEBHOOK}). Updating..."
            curl -s -X PATCH \
                -H "Authorization: token ${GITHUB_TOKEN}" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/${full_repo}/hooks/${EXISTING_WEBHOOK}" \
                -d "{\"config\":{\"url\":\"${JENKINS_URL}\",\"content_type\":\"json\"},\"active\":true,\"events\":[\"push\",\"pull_request\"]}" > /dev/null
            echo "   ✅ Webhook updated!"
        else
            echo "   Creating new webhook..."
            curl -s -X POST \
                -H "Authorization: token ${GITHUB_TOKEN}" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/${full_repo}/hooks" \
                -d "{\"name\":\"web\",\"config\":{\"url\":\"${JENKINS_URL}\",\"content_type\":\"json\"},\"active\":true,\"events\":[\"push\",\"pull_request\"]}" > /dev/null
            echo "   ✅ Webhook created!"
        fi
    fi
}

# Configure webhooks for all repositories
for repo in "${REPOS[@]}"; do
    configure_webhook "$repo"
    echo ""
done

echo "🎉 All webhooks configured successfully!"
echo ""
echo "📋 Summary:"
echo "   Jenkins URL: ${JENKINS_URL}"
echo "   Organization: ${GITHUB_ORG}"
echo "   Repositories: ${#REPOS[@]}"
echo ""
echo "🧪 Test your webhooks:"
echo "   1. Make a commit to any repository"
echo "   2. Check Jenkins for automatic build trigger"
echo "   3. Or check webhook deliveries in GitHub repo settings"
