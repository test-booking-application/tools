# Jenkins Auto-Configuration Setup

This Jenkins deployment uses **Configuration as Code (JCasC)** to automatically configure credentials and jobs on startup.

## 🔧 What's Auto-Configured

### ✅ Credentials (Pre-configured)
1. **SonarCloud Token** (`sonar-token`)
   - Already configured in `values.yaml`
   - No action needed

### ⚠️ Credentials (Need Manual Setup)
2. **AWS ECR Credentials** (`aws-ecr-creds`)
   - **Before deploying Jenkins**, get your ECR password:
     ```bash
     aws ecr get-login-password --region us-east-1
     ```
   - Update `values.yaml` line 80:
     ```yaml
     password: "YOUR_ECR_PASSWORD_HERE"
     ```

3. **GitHub Token** (`github-token`)
   - Create a GitHub Personal Access Token:
     - Go to: https://github.com/settings/tokens
     - Generate new token (classic)
     - Scopes needed: `repo`, `admin:org`, `admin:repo_hook`
   - Update `values.yaml` line 87:
     ```yaml
     secret: "YOUR_GITHUB_TOKEN_HERE"
     ```

### ✅ Jobs (Auto-created)
- **GitHub Organization Folder**: `test-booking-application`
  - Auto-discovers all repos with `Jenkinsfile`
  - Scans every 15 minutes for new repos
  - Creates jobs automatically

## 🚀 Deployment Steps

### 1. Update Credentials in values.yaml

```bash
cd tools/cicd/jenkins
# Edit values.yaml and replace placeholders
nano values.yaml
```

Replace these lines:
- Line 80: `password: "{AQAAABAAAAAwZXByZXNzaW9uIHBsYWNlaG9sZGVyfQ==}"`
  → `password: "YOUR_ECR_PASSWORD"`
  
- Line 87: `secret: "{AQAAABAAAAAwR2l0SHViIFRva2VuIFBsYWNlaG9sZGVyfQ==}"`
  → `secret: "YOUR_GITHUB_TOKEN"`

### 2. Deploy Jenkins

```bash
helm dependency update
helm upgrade --install jenkins . -n jenkins --create-namespace -f values.yaml
```

### 3. Access Jenkins

```bash
# Port-forward
kubectl port-forward svc/jenkins 8080:8080 -n jenkins

# Or use the access script
../../access-tools.sh
```

Open: http://localhost:8080
Login: `admin` / `admin`

### 4. Verify Auto-Configuration

1. Go to **Manage Jenkins** → **Credentials**
   - You should see: `sonar-token`, `aws-ecr-creds`, `github-token`

2. Go to **Dashboard**
   - You should see: `Ticket Booking Microservices` folder
   - It will auto-scan and create jobs for each repo

## 🔄 After Destroy/Recreate

Since credentials are in `values.yaml`, you only need to:

1. **Get fresh ECR password** (changes every 12 hours):
   ```bash
   aws ecr get-login-password --region us-east-1
   ```

2. **Update values.yaml** with new password

3. **Redeploy Jenkins**:
   ```bash
   helm upgrade --install jenkins . -n jenkins -f values.yaml
   ```

Everything else (SonarCloud token, GitHub token, jobs) will be auto-configured!

## 🔒 Security Note

**WARNING:** The `values.yaml` file now contains secrets. 

**Do NOT commit this file with real credentials to Git!**

Options:
1. Use `.gitignore` to exclude `values.yaml`
2. Use Kubernetes Secrets instead (more secure)
3. Use a secrets manager (AWS Secrets Manager, Vault)

For learning purposes, the current approach is acceptable, but for production, use proper secrets management.

## 📚 What Gets Auto-Created

When Jenkins starts, it will:

1. ✅ Create all credentials
2. ✅ Create GitHub Organization Folder
3. ✅ Scan `test-booking-application` organization
4. ✅ Discover repos: `user-service`, `ticket-service`, `booking-service`, `frontend`, `api-gateway`
5. ✅ Create Multibranch Pipeline jobs for each
6. ✅ Trigger initial builds

**Zero manual configuration needed!** 🎉
