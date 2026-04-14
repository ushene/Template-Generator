# Project Structure Examples

This guide shows recommended project structures for different application types and languages.

## 📁 .NET Azure Function App

```
my-dotnet-function/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── src/
│   ├── MyFunction.cs
│   ├── Startup.cs
│   └── MyFunction.csproj
├── tests/
│   ├── MyFunction.Tests.csproj
│   └── MyFunctionTests.cs
├── deployment/
│   └── parameters.json
├── host.json
├── local.settings.json
├── .gitignore
└── README.md
```

### Key Files for CI/CD:
- `*.csproj` - Project definition
- `tests/*.csproj` - Test project
- CI will: Restore → Build → Test → Package as ZIP → Publish to JFrog
- CD will: Download ZIP → Deploy to Azure Functions

---

## 📁 Python Azure App Service

```
my-python-webapp/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── routes/
│   │   ├── __init__.py
│   │   └── api.py
│   └── models/
│       ├── __init__.py
│       └── user.py
├── tests/
│   ├── __init__.py
│   ├── test_main.py
│   └── test_api.py
├── deployment/
│   └── app-service-config.json
├── requirements.txt
├── pytest.ini
├── .gitignore
└── README.md
```

### Key Files for CI/CD:
- `requirements.txt` - Python dependencies
- `pytest.ini` - Test configuration
- CI will: Install deps → Run tests → Package → Publish to JFrog
- CD will: Download package → Deploy to App Service

---

## 📁 Node.js Application (AKS)

```
my-node-api/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── src/
│   ├── index.ts
│   ├── server.ts
│   ├── routes/
│   │   ├── index.ts
│   │   └── api.ts
│   └── controllers/
│       └── userController.ts
├── tests/
│   ├── unit/
│   │   └── user.test.ts
│   └── integration/
│       └── api.test.ts
├── deployment/
│   ├── kubernetes/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   └── helm/
│       └── values.yaml
├── dist/               # Build output
├── Dockerfile
├── .dockerignore
├── package.json
├── package-lock.json
├── tsconfig.json
├── jest.config.js
├── .gitignore
└── README.md
```

### Key Files for CI/CD:
- `package.json` - Node dependencies and scripts
- `Dockerfile` - Container definition (for AKS)
- `deployment/kubernetes/*.yaml` - K8s manifests
- CI will: Install → Build → Test → Package → Publish to JFrog
- CD will: Build Docker image → Push to ACR → Deploy to AKS

---

## 📁 .NET Web API (IIS)

```
my-dotnet-api/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── src/
│   ├── Controllers/
│   │   └── UsersController.cs
│   ├── Models/
│   │   └── User.cs
│   ├── Services/
│   │   └── UserService.cs
│   ├── Program.cs
│   ├── Startup.cs
│   └── MyApi.csproj
├── tests/
│   ├── UnitTests/
│   │   └── UserServiceTests.cs
│   └── IntegrationTests/
│       └── UsersControllerTests.cs
├── deployment/
│   ├── web.config
│   └── iis-setup.ps1
├── .gitignore
└── README.md
```

### Key Files for CI/CD:
- `*.csproj` - Project definition
- `web.config` - IIS configuration
- CI will: Restore → Build → Test → Publish → Package → Upload to JFrog
- CD will: Download → Extract → Deploy to IIS → Restart App Pool

---

## 📁 Azure Logic Apps

```
my-logic-app/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── LogicApp/
│   ├── workflow.json
│   ├── connections.json
│   └── parameters.json
├── deployment/
│   ├── arm-template.json
│   └── parameters/
│       ├── dev.json
│       ├── staging.json
│       └── prod.json
├── tests/
│   └── workflow-validation.ps1
├── .gitignore
└── README.md
```

### Key Files for CI/CD:
- `workflow.json` - Logic App definition
- `arm-template.json` - Azure Resource Manager template
- CI will: Validate → Package ARM templates → Publish to JFrog
- CD will: Download → Deploy ARM template → Configure connections

---

## 📁 Azure Data & ETL Application (Python)

```
my-etl-pipeline/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── pipelines/
│   ├── __init__.py
│   ├── extract.py
│   ├── transform.py
│   └── load.py
├── config/
│   ├── development.yaml
│   ├── staging.yaml
│   └── production.yaml
├── tests/
│   ├── test_extract.py
│   ├── test_transform.py
│   └── test_load.py
├── deployment/
│   └── azure-data-factory/
│       ├── pipeline.json
│       └── linkedServices.json
├── requirements.txt
├── setup.py
├── .gitignore
└── README.md
```

### Key Files for CI/CD:
- `requirements.txt` - Python dependencies
- `pipelines/*.py` - ETL logic
- `deployment/*.json` - Azure Data Factory configs
- CI will: Install → Test → Package → Publish to JFrog
- CD will: Download → Deploy to Azure Data Factory

---

## 📁 Azure Cognitive AI App (.NET)

```
my-ai-app/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── src/
│   ├── Services/
│   │   ├── AzureOpenAIService.cs
│   │   ├── CognitiveSearchService.cs
│   │   └── DocumentIntelligenceService.cs
│   ├── Models/
│   │   └── AIModels.cs
│   ├── Controllers/
│   │   └── AIController.cs
│   └── MyAIApp.csproj
├── tests/
│   ├── ServiceTests/
│   │   └── OpenAIServiceTests.cs
│   └── IntegrationTests/
│       └── AIWorkflowTests.cs
├── deployment/
│   ├── cognitive-services.json
│   └── app-settings.json
├── appsettings.json
├── .gitignore
└── README.md
```

### Key Files for CI/CD:
- `*.csproj` - Project definition
- `appsettings.json` - Configuration (use secrets for keys)
- CI will: Restore → Build → Test → Package → Publish to JFrog
- CD will: Download → Deploy to Azure → Configure Cognitive Services

---

## 🔧 Common Configuration Files

### .gitignore (All Projects)

```gitignore
# Build outputs
bin/
obj/
dist/
build/
publish/
*.zip

# Dependencies
node_modules/
venv/
.venv/

# Secrets (NEVER commit!)
*.env
*secrets*
appsettings.*.json
local.settings.json

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Logs
*.log
```

### Health Check Endpoints

All applications should implement a health check endpoint:

**ASP.NET Core:**
```csharp
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));
```

**Python (FastAPI):**
```python
@app.get("/health")
async def health():
    return {"status": "healthy"}
```

**Node.js (Express):**
```javascript
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});
```

---

## 📝 Required Files Checklist

### Every Project Needs:

- [ ] **README.md** - Project documentation
- [ ] **.gitignore** - Prevent committing sensitive files
- [ ] **Health endpoint** - For deployment verification
- [ ] **Tests** - Unit and/or integration tests
- [ ] **Dependency file** - requirements.txt, package.json, or *.csproj
- [ ] **Configuration** - Parameterized, no hardcoded secrets

### For Containerized Deployments (AKS):

- [ ] **Dockerfile** - Container definition
- [ ] **.dockerignore** - Exclude unnecessary files from image
- [ ] **deployment/kubernetes/*.yaml** - K8s manifests

### For IIS Deployments:

- [ ] **web.config** - IIS configuration
- [ ] **deployment scripts** - PowerShell for IIS setup

---

## 🎯 Best Practices

### 1. Separate Environments

Use environment-specific configuration:
```
config/
├── development.json
├── staging.json
└── production.json
```

### 2. Never Commit Secrets

Use GitHub Secrets and environment variables:
```yaml
# Good: Use secrets
connectionString: ${{ secrets.DB_CONNECTION }}

# Bad: Hardcoded
connectionString: "Server=prod-db;..."
```

### 3. Health Checks

Implement comprehensive health checks:
```
/health          - Basic liveness
/health/ready    - Readiness (dependencies ok)
/health/detailed - Detailed status (admin only)
```

### 4. Versioning

Tag releases and include version in deployment:
```bash
git tag v1.2.3
git push --tags
```

### 5. Documentation

Document:
- Setup instructions
- Configuration requirements
- Deployment process
- Rollback procedures

---

**Next Step:** Follow the [Quick Start Guide](QUICKSTART.md) to generate your CI/CD templates!
