# Architecture & Workflow

This document explains how the Template Generator Tool works and the flow of generated pipelines.

## 🏗️ Tool Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface                           │
│         (GitHub Actions Workflow Dispatch UI)                │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Application  │  │   Language   │  │ Deployment   │      │
│  │     Type     │  │              │  │     Type     │      │
│  │  (dropdown)  │  │  (dropdown)  │  │  (dropdown)  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌──────────────────────────────────────────────────┐      │
│  │           Project Name (text input)              │      │
│  └──────────────────────────────────────────────────┘      │
│                                                              │
│                  [Run Workflow Button]                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           GitHub Actions Runner (Ubuntu)                     │
│                                                              │
│  1. Checkout repository                                      │
│  2. Setup PowerShell                                         │
│  3. Execute generate-templates.ps1                          │
│     │                                                        │
│     ├──> Load template-functions.ps1                        │
│     ├──> Generate CI Template                               │
│     ├──> Generate CD Template                               │
│     └──> Generate Configuration Guide                       │
│                                                              │
│  4. Upload artifacts (templates + guide)                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 Generated Artifacts                          │
│                                                              │
│  📄 ci-{lang}-{apptype}.yml                                 │
│  📄 cd-{deploy}-{lang}-{apptype}.yml                        │
│  📄 CONFIGURATION-GUIDE.md                                  │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 CI Pipeline Workflow

```
┌──────────────┐
│   Git Push   │  (to main, develop, or feature/*)
│   PR Created │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│                  CI Pipeline Triggered                       │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Checkout   │────▶│ Setup SDK    │────▶│   Restore    │
│     Code     │     │ (.NET/Py/Node│     │ Dependencies │
└──────────────┘     └──────────────┘     └──────────────┘
                                                  │
                                                  ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Package    │◀────│   Run Tests  │◀────│    Build     │
│ Application  │     │   + Coverage │     │ Application  │
└──────┬───────┘     └──────────────┘     └──────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│              Security & Quality Scanning                     │
│                                                              │
│  ┌──────────────┐              ┌──────────────┐            │
│  │  SonarQube   │              │     Snyk     │            │
│  │ Code Quality │              │ Vulnerability│            │
│  │   Analysis   │              │   Scanning   │            │
│  └──────────────┘              └──────────────┘            │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│           Publish Artifacts to JFrog Artifactory            │
│                                                              │
│  Package: {app-name}-{version}.zip                          │
│  Path: {repository}/{app-name}/{version}/                   │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│   Success    │  ✅ Build #42 Complete
└──────────────┘
```

## 🚀 CD Pipeline Workflow

### Azure Deployment

```
┌──────────────────────────────────────────────────────────────┐
│           Manual Trigger (workflow_dispatch)                 │
│                                                               │
│  Environment: [development/staging/production]                │
│  Version: [build number from CI]                             │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Download from JFrog Artifactory                 │
│                                                              │
│  jfrog rt download {repo}/{app}/{version}/*.zip             │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                Pre-Deployment Validation                     │
│                                                              │
│  ✓ Azure CLI installed                                      │
│  ✓ Login to Azure (service principal)                       │
│  ✓ Verify target resource exists                            │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Deploy to Azure                           │
│                                                              │
│  Azure Functions:  az functionapp deployment source         │
│  App Service:      az webapp deployment source              │
│  Container Apps:   az containerapp update                   │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Post-Deployment Verification                    │
│                                                              │
│  ┌──────────────┐        ┌──────────────┐                  │
│  │ Health Check │───────▶│ Smoke Tests  │                  │
│  │  (10 retries)│        │   (basic)    │                  │
│  └──────────────┘        └──────────────┘                  │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
                  ┌─────────┐
                  │ Success │  ✅ Deployed to {env}
                  └─────────┘
```

### AKS Deployment

```
┌──────────────────────────────────────────────────────────────┐
│           Manual Trigger (workflow_dispatch)                 │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Build Docker Image                          │
│                                                              │
│  docker build -t {acr}.azurecr.io/{app}:{version} .        │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│             Push to Azure Container Registry                 │
│                                                              │
│  docker login {acr}.azurecr.io                              │
│  docker push {acr}.azurecr.io/{app}:{version}               │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Pre-Deployment Validation                       │
│                                                              │
│  ✓ Get AKS credentials                                      │
│  ✓ kubectl cluster-info                                     │
│  ✓ Verify namespace exists                                  │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 Deploy to Kubernetes                         │
│                                                              │
│  kubectl set image deployment/{app} \                       │
│    {app}={acr}.azurecr.io/{app}:{version}                   │
│                                                              │
│  kubectl rollout status deployment/{app}                    │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         Post-Deployment Verification                         │
│                                                              │
│  ✓ Pods running                                             │
│  ✓ Service accessible                                       │
│  ✓ Health checks passing                                    │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
                  ┌─────────┐
                  │ Success │  ✅ Deployed to AKS
                  └─────────┘
```

### IIS Deployment

```
┌──────────────────────────────────────────────────────────────┐
│           Manual Trigger (workflow_dispatch)                 │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Download from JFrog Artifactory                 │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Pre-Deployment Validation                       │
│                                                              │
│  ✓ Test connection to IIS server (Port 5985)               │
│  ✓ Create PowerShell remote session                         │
│  ✓ Verify IIS site exists                                   │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│        Copy Package to Remote Server                         │
│                                                              │
│  Copy-Item {package} -ToSession $session                     │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           Execute Deployment on IIS Server                   │
│                                                              │
│  1. Stop-WebAppPool                                         │
│  2. Backup current deployment                               │
│  3. Extract new package                                     │
│  4. Start-WebAppPool                                        │
│  5. Verify site is running                                  │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         Post-Deployment Verification                         │
│                                                              │
│  ✓ Website responds                                         │
│  ✓ Health check passes                                      │
│  ✓ Application pool running                                 │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
                  ┌─────────┐
                  │ Success │  ✅ Deployed to IIS
                  └─────────┘
```

## 🔐 Security Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   GitHub Repository                          │
│                                                              │
│  Settings ─▶ Secrets and Variables ─▶ Actions              │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Encrypted Secrets                           │
│                                                              │
│  • JFROG_PASSWORD                                           │
│  • AZURE_CLIENT_SECRET                                      │
│  • IIS_PASSWORD                                             │
│  • etc...                                                   │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions Runner                           │
│                                                              │
│  Secrets injected as environment variables:                 │
│  ${{ secrets.SECRET_NAME }}                                 │
│                                                              │
│  ⚠️  Secrets are masked in logs                             │
│  ⚠️  Never echo or print secrets                            │
└─────────────────────────────────────────────────────────────┘
```

## 📊 Data Flow

```
Developer            GitHub              JFrog             Deployment Target
    │                   │                   │                      │
    │   git push        │                   │                      │
    ├──────────────────▶│                   │                      │
    │                   │                   │                      │
    │                   │  CI Workflow      │                      │
    │                   ├─────build────────▶│                      │
    │                   │                   │                      │
    │                   │                   │  artifact stored     │
    │                   │                   │  {app}-{version}.zip │
    │                   │                   │                      │
    │  trigger deploy   │                   │                      │
    ├──────────────────▶│                   │                      │
    │                   │                   │                      │
    │                   │  CD Workflow      │                      │
    │                   ├──────download────▶│                      │
    │                   │◀─────package──────┤                      │
    │                   │                   │                      │
    │                   ├───────────────────────deploy────────────▶│
    │                   │                   │                      │
    │                   │                   │         verify       │
    │                   │◀─────────────────────health check───────┤
    │                   │                   │                      │
    │  ✅ Deployed      │                   │                      │
    │◀──────────────────┤                   │                      │
```

## 🔄 Version Flow

```
┌─────────────┐
│   Commit    │  git commit -m "feature"
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Git Push   │  git push origin feature/new-feature
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────┐
│        CI Build Triggered            │
│  Version = github.run_number (42)    │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│     Package Created & Published      │
│  my-app-42.zip → JFrog              │
└──────┬───────────────────────────────┘
       │
       ├─────────────┐
       │             │
       ▼             ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│   Dev    │  │ Staging  │  │   Prod   │
│ Deploy   │  │ Deploy   │  │ Deploy   │
│ v42      │  │ v42      │  │ v42      │
└──────────┘  └──────────┘  └──────────┘
```

## 🎯 Environment Promotion Strategy

```
Development                 Staging                  Production
    │                          │                         │
    │  Auto-deploy on CI       │  Manual trigger         │  Manual trigger
    │  (optional)              │  + Approval             │  + Multiple approvals
    │                          │                         │
    ▼                          ▼                         ▼
┌──────────┐              ┌──────────┐              ┌──────────┐
│ Test new │              │ QA & UAT │              │ Live     │
│ features │              │ testing  │              │ users    │
└──────────┘              └──────────┘              └──────────┘
    │                          │                         │
    │  ✅ Validated            │  ✅ Approved            │  ✅ Deployed
    │                          │                         │
    └──────────▶ Promote ─────┴──────────▶ Promote ────┘
```

## 💡 Key Design Principles

### 1. **Parameterization**
- No hardcoded values in templates
- All configuration via GitHub Secrets
- Environment-specific configurations

### 2. **Security First**
- Secrets never in code
- Encrypted at rest in GitHub
- Masked in logs

### 3. **Reusability**
- Templates work for any project
- Functions are modular
- Easy to extend

### 4. **Observability**
- Comprehensive logging
- Health checks at every stage
- Clear success/failure indicators

### 5. **Fail-Safe**
- Pre-deployment validation
- Post-deployment verification
- Rollback capabilities

---

## 📈 Scalability

This tool scales to support:

- **Multiple teams**: Each team uses same tool with their configs
- **Multiple projects**: Generate templates for any number of projects
- **Multiple environments**: Dev, staging, prod, and more
- **Multiple regions**: Deploy to different Azure regions

---

**Visual learner?** Check the [Quick Start Guide](QUICKSTART.md) for a step-by-step walkthrough!
