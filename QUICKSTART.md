# Quick Start Guide

Get your CI/CD pipelines up and running in 10 minutes!

## ⚡ Step-by-Step Guide

### 1️⃣ Prerequisites Check (2 minutes)

Before starting, ensure you have:

- [ ] GitHub repository with Actions enabled
- [ ] JFrog Artifactory account
- [ ] Access to deployment target (Azure/AKS/IIS)
- [ ] Admin access to GitHub repository settings

### 2️⃣ Copy Files to Repository (1 minute)

Copy these files to your repository:

```
your-repo/
├── .github/
│   └── workflows/
│       └── template-generator.yml
├── scripts/
│   ├── generate-templates.ps1
│   └── template-functions.ps1
└── examples/
    └── DOCKERFILE-EXAMPLES.md
```

**Quick command:**
```bash
# If you cloned this template repository
cp -r .github/ your-repo/
cp -r scripts/ your-repo/
cp -r examples/ your-repo/
```

### 3️⃣ Configure Secrets (3 minutes)

Go to: `Your Repository` → `Settings` → `Secrets and variables` → `Actions`

#### Minimum Required Secrets

Click **"New repository secret"** and add:

**JFrog (Required for all):**
```
JFROG_URL           → https://yourcompany.jfrog.io
JFROG_REPOSITORY    → your-repo-name
JFROG_USERNAME      → your-username
JFROG_PASSWORD      → your-api-token
```

**Choose ONE deployment type and add its secrets:**

<details>
<summary>Azure Deployment Secrets</summary>

```
AZURE_SUBSCRIPTION_ID  → your-subscription-id
AZURE_TENANT_ID        → your-tenant-id
AZURE_CLIENT_ID        → your-client-id
AZURE_CLIENT_SECRET    → your-client-secret
AZURE_RESOURCE_GROUP   → your-resource-group
AZURE_APP_NAME         → your-app-name
```
</details>

<details>
<summary>AKS Deployment Secrets</summary>

```
AZURE_SUBSCRIPTION_ID  → your-subscription-id
AKS_CLUSTER_NAME       → your-aks-cluster
AKS_RESOURCE_GROUP     → your-aks-rg
ACR_NAME               → yourregistry
ACR_USERNAME           → acr-username
ACR_PASSWORD           → acr-password
KUBERNETES_NAMESPACE   → default (or your namespace)
```
</details>

<details>
<summary>IIS Deployment Secrets</summary>

```
IIS_SERVER       → server.domain.com
IIS_SITE_NAME    → Default Web Site
IIS_APP_POOL     → YourAppPool
IIS_DEPLOY_PATH  → C:\inetpub\wwwroot\yourapp
IIS_USERNAME     → DOMAIN\username
IIS_PASSWORD     → your-password
```
</details>

### 4️⃣ Generate Templates (2 minutes)

1. Go to **Actions** tab in GitHub
2. Click **"Template Generator Tool"**
3. Click **"Run workflow"**
4. Fill in the form:

   | Field | Example |
   |-------|---------|
   | Application Type | Azure Function Apps |
   | Language | .NET |
   | Deployment Type | Azure |
   | Project Name | my-awesome-app |

5. Click **"Run workflow"** green button

### 5️⃣ Download and Use Templates (2 minutes)

1. Wait for workflow to complete (usually < 1 minute)
2. Click on the completed workflow run
3. Scroll to **Artifacts** section
4. Download `generated-templates-{your-project-name}`
5. Extract the ZIP file

You'll get:
- 📄 `ci-*.yml` - Your CI pipeline
- 📄 `cd-*.yml` - Your CD pipeline
- 📄 `CONFIGURATION-GUIDE.md` - Detailed setup instructions

### 6️⃣ Deploy Templates

```bash
# Copy templates to your workflows directory
cp generated/ci-*.yml .github/workflows/ci.yml
cp generated/cd-*.yml .github/workflows/cd.yml

# Commit and push
git add .github/workflows/
git commit -m "Add CI/CD pipelines"
git push
```

**That's it!** 🎉 Your CI pipeline will run automatically!

---

## 🚀 Next Steps

### Test Your CI Pipeline

Your CI pipeline should automatically trigger. Watch it run:

1. Go to **Actions** tab
2. You should see a new run of **"CI - Build and Test"**
3. Click on it to watch the progress

### Run Your First Deployment

1. Go to **Actions** tab
2. Select **"CD - Deploy to {target}"**
3. Click **"Run workflow"**
4. Enter:
   - **Environment**: `development`
   - **Version**: Use the build number from your CI run (e.g., `42`)
5. Click **"Run workflow"**

### Customize Your Templates

Open the generated templates and review:

- [ ] SDK versions match your project
- [ ] Test commands are correct
- [ ] Deployment paths are accurate
- [ ] Health check URLs are correct

---

## 📞 Common Issues

### ❌ "Secrets not found"

**Solution:** Double-check secret names match exactly (case-sensitive)

```
Settings → Secrets → Check spelling
```

### ❌ "JFrog authentication failed"

**Solution:** Verify JFrog credentials

```bash
# Test JFrog credentials manually
curl -u username:password https://yourcompany.jfrog.io/artifactory/api/system/ping
```

### ❌ "Azure login failed"

**Solution:** Verify service principal has access

```bash
# Test Azure credentials
az login --service-principal -u $CLIENT_ID -p $CLIENT_SECRET --tenant $TENANT_ID
```

### ❌ "Build failed"

**Solution:** Check SDK version in template matches your project

```yaml
# In generated CI template, update this section:
- name: Setup .NET SDK
  uses: actions/setup-dotnet@v4
  with:
    dotnet-version: '8.x'  # ← Change this to match your project
```

---

## 💡 Pro Tips

### Tip 1: Use Environment Protection

Protect production deployments:

```
Settings → Environments → Add environment "production"
→ Check "Required reviewers"
→ Add team members
```

### Tip 2: Start with Development

Always test in development first:

```
1. Deploy to development ✓
2. Verify application works ✓
3. Deploy to staging ✓
4. Final check ✓
5. Deploy to production ✓
```

### Tip 3: Keep Versions Organized

Use semantic versioning in JFrog:

```
major.minor.patch-buildnumber
Example: 1.2.3-42
```

### Tip 4: Monitor Your Deployments

Set up notifications:

```
Repository → Settings → Notifications
→ Enable workflow run notifications
```

---

## 📚 Additional Resources

- [Full README](../README.md) - Complete documentation
- [Dockerfile Examples](DOCKERFILE-EXAMPLES.md) - For AKS deployments
- [Configuration Guide](generated/CONFIGURATION-GUIDE.md) - Generated with templates

---

## 🎯 Checklist

Use this checklist for first-time setup:

- [ ] Files copied to repository
- [ ] JFrog secrets configured
- [ ] Deployment secrets configured
- [ ] Templates generated
- [ ] Templates downloaded
- [ ] CI pipeline added and running
- [ ] CD pipeline added and tested
- [ ] Health checks working
- [ ] Documentation reviewed

---

**⏱️ Total Time: ~10 minutes**

**Questions?** Check the generated `CONFIGURATION-GUIDE.md` for detailed troubleshooting!
