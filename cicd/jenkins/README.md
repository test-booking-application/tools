# Jenkins Auto-Configuration with Kubernetes Secrets

This Jenkins deployment uses **Configuration as Code (JCasC)** with **Kubernetes Secrets** for secure credential management.

## 🔒 Security Approach

Credentials are stored as **Kubernetes Secrets** (not in `values.yaml`), which is:
- ✅ More secure (secrets encrypted at rest)
- ✅ Not committed to Git
- ✅ Easy to rotate
- ✅ Production-ready

## 🚀 Quick Start

### 1. Create Credentials Secret

Run the setup script:

```bash
cd tools/cicd/jenkins
./setup-credentials.sh
```

This will:
1. Get your AWS ECR password automatically
2. Prompt you for GitHub Personal Access Token
3. Create a Kubernetes Secret with all credentials

**GitHub Token Setup:**
- Go to: https://github.com/settings/tokens?type=beta
- Create **Fine-grained token**:
  - Name: `Jenkins CI/CD`
  - Expiration: 90 days
  - Resource owner: `test-booking-application`
  - Repository access: All repositories
  - Permissions:
    - Contents: Read-only
    - Metadata: Read-only  
    - Webhooks: Read and write

### 2. Deploy Jenkins

```bash
helm dependency update
helm upgrade --install jenkins . -n jenkins --create-namespace -f values.yaml
```

### 3. Access Jenkins

```bash
# Port-forward
kubectl port-forward svc/jenkins 8080:8080 -n jenkins

# Or use access script
../../access-tools.sh
```

Open: http://localhost:8080  
Login: `admin` / `admin`

## ✅ What Gets Auto-Configured

When Jenkins starts, it automatically:

1. **Credentials** (from Kubernetes Secret):
   - ✅ `sonar-token` - SonarCloud authentication
   - ✅ `aws-ecr-creds` - AWS ECR push/pull
   - ✅ `github-token` - GitHub API access

2. **Jobs**:
   - ✅ GitHub Organization Folder: `test-booking-application`
   - ✅ Auto-discovers repos with `Jenkinsfile`
   - ✅ Creates Multibranch Pipeline jobs
   - ✅ Scans every 15 minutes

3. **Plugins**:
   - All required plugins pre-installed

## 🔄 After Destroy/Recreate

Since ECR password expires every 12 hours, you'll need to refresh it:

```bash
cd tools/cicd/jenkins
./setup-credentials.sh
```

Then redeploy:

```bash
helm upgrade --install jenkins . -n jenkins -f values.yaml
```

Everything else (GitHub token, SonarCloud token) persists until you change them.

## 🔐 Security Best Practices

### ✅ What We're Doing Right:
- Secrets stored in Kubernetes (encrypted at rest)
- Not committed to Git
- Fine-grained GitHub tokens
- ECR password auto-rotates every 12 hours

### 🔒 For Production:
- Use AWS Secrets Manager or HashiCorp Vault
- Enable Kubernetes Secret encryption
- Use IRSA (IAM Roles for Service Accounts) for AWS
- Rotate GitHub tokens regularly

## 📋 Verifying Setup

After deployment, verify in Jenkins:

1. **Credentials:**
   - Go to: Manage Jenkins → Credentials
   - Should see: `sonar-token`, `aws-ecr-creds`, `github-token`

2. **Jobs:**
   - Dashboard should show: `Ticket Booking Microservices` folder
   - It will scan and create jobs for:
     - user-service
     - ticket-service
     - booking-service
     - frontend
     - api-gateway

3. **First Build:**
   - Jobs will trigger automatically
   - Check build logs for any issues

## 🛠️ Troubleshooting

### Secret not found error:
```bash
# Verify secret exists
kubectl get secret jenkins-credentials -n jenkins

# Check secret contents (base64 encoded)
kubectl get secret jenkins-credentials -n jenkins -o yaml
```

### ECR authentication fails:
```bash
# Refresh ECR password
./setup-credentials.sh
helm upgrade --install jenkins . -n jenkins -f values.yaml
```

### GitHub scanning fails:
- Verify token has correct permissions
- Check token hasn't expired
- Ensure organization name is correct

## 📚 What Happens on Deploy

1. Kubernetes creates `jenkins-credentials` Secret
2. Jenkins pod starts
3. Secret values injected as environment variables
4. JCasC reads environment variables
5. Credentials created in Jenkins
6. Organization Folder created
7. GitHub scan triggered
8. Jobs created automatically
9. Initial builds start

**Zero manual configuration needed!** 🎉
