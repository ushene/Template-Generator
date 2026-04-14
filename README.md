# GitHub Actions Template Generator Tool

A reusable GitHub Actions workflow that provides an interactive UI for generating customized CI/CD pipeline templates for various Azure services, programming languages, and deployment targets.

## 🚀 Features

- **Interactive UI**: Easy-to-use dropdown selections for configuration
- **Multi-Language Support**: .NET, Python, and Node.js
- **Multiple Azure Services**: 
  - Azure Function Apps
  - Azure App Service
  - Azure Container Apps
  - Azure Logic Apps
  - Azure API Management
  - Azure Data & ETL Applications
  - Azure Cognitive AI Apps
- **Flexible Deployment**: IIS, AKS, or Azure native deployments
- **Comprehensive CI Pipeline**: Build, test, security scan, and publish to JFrog
- **Production-Ready CD Pipeline**: Automated deployment with health checks
- **Fully Parameterized**: No hardcoded values, all configurable via secrets
- **Well-Documented**: Extensive comments and configuration guides

## 📋 Prerequisites

- GitHub repository with Actions enabled
- JFrog Artifactory account and repository
- Appropriate deployment target (Azure subscription, AKS cluster, or IIS server)
- Required secrets configured in GitHub repository

## 🎯 Quick Start

### 1. Add to Your Repository

Copy this entire repository structure to your GitHub repository:

```
.github/
  workflows/
    template-generator.yml
scripts/
  generate-templates.ps1
  template-functions.ps1
README.md
```

### 2. Configure GitHub Secrets

Go to your repository Settings > Secrets and variables > Actions and add the required secrets:

#### Required JFrog Secrets
- `JFROG_URL`
- `JFROG_REPOSITORY`
- `JFROG_USERNAME`
- `JFROG_PASSWORD`

#### Deployment-Specific Secrets

**For Azure deployments:**
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_RESOURCE_GROUP`
- `AZURE_APP_NAME`

**For AKS deployments:**
- `AKS_CLUSTER_NAME`
- `AKS_RESOURCE_GROUP`
- `ACR_NAME`
- `ACR_USERNAME`
- `ACR_PASSWORD`
- `KUBERNETES_NAMESPACE`

**For IIS deployments:**
- `IIS_SERVER`
- `IIS_SITE_NAME`
- `IIS_APP_POOL`
- `IIS_DEPLOY_PATH`
- `IIS_USERNAME`
- `IIS_PASSWORD`

### 3. Generate Templates

1. Go to the **Actions** tab in your GitHub repository
2. Select **"Template Generator Tool"** workflow
3. Click **"Run workflow"** button
4. Fill in the form:
   - **Application Type**: Select your Azure service type
   - **Language**: Choose .NET, Python, or Node
   - **Deployment Type**: Select IIS, AKS, or Azure
   - **Project Name**: Enter your project name
5. Click **"Run workflow"** to generate templates

### 4. Download Generated Templates

1. Wait for the workflow to complete
2. Download the artifacts from the workflow run
3. Extract the files:
   - `ci-{language}-{app-type}.yml` - CI pipeline template
   - `cd-{deployment}-{language}-{app-type}.yml` - CD pipeline template
   - `CONFIGURATION-GUIDE.md` - Detailed setup instructions

### 5. Implement Templates

1. Copy the generated CI template to `.github/workflows/ci.yml`
2. Copy the generated CD template to `.github/workflows/cd.yml`
3. Review and customize based on the Configuration Guide
4. Commit and push to trigger your first CI build

## 📖 Template Components

### CI Pipeline Features

- **Environment Setup**: Automatic SDK/runtime installation
- **Dependency Management**: Smart dependency restoration
- **Build Process**: Configurable build with multiple configurations
- **Testing**: Unit tests with coverage reporting
- **Security Scanning**: 
  - SonarQube code quality analysis (optional)
  - Snyk vulnerability scanning (optional)
- **Artifact Packaging**: Application-specific packaging
- **JFrog Publishing**: Automatic artifact publishing to JFrog Artifactory
- **GitHub Artifacts**: Backup artifact storage

### CD Pipeline Features

- **Environment Management**: Development, staging, and production
- **Version Control**: Deploy specific versions from JFrog
- **Pre-Deployment Validation**: Target verification before deployment
- **Deployment Strategies**:
  - Azure: Native Azure service deployment
  - AKS: Docker containerization and Kubernetes deployment
  - IIS: Remote PowerShell deployment with app pool management
- **Health Checks**: Automated post-deployment validation
- **Smoke Tests**: Basic functionality verification
- **Rollback Support**: Manual rollback capabilities

## 🔧 Customization

### Modifying the Generator

Edit `scripts/template-functions.ps1` to customize:

- Build commands and steps
- Test execution logic
- Packaging strategies
- Deployment procedures
- Environment variables

### Template Variables

All generated templates use parameterized values:

- Build configurations are configurable via environment variables
- No hardcoded URLs, paths, or credentials
- All secrets pulled from GitHub Secrets
- Comments explain each configurable section

## 📊 Workflow Diagram

```
User Input (UI)
    ↓
Template Generator Workflow
    ↓
PowerShell Script
    ↓
Template Functions
    ↓
Generated Templates (CI + CD + Guide)
    ↓
Downloadable Artifacts
```

## 🎨 Example Usage

### Example 1: .NET Azure Function App

**Input:**
- Application Type: Azure Function Apps
- Language: .NET
- Deployment Type: Azure
- Project Name: my-function-app

**Output:**
- `ci-dotnet-azure-function-apps.yml`
- `cd-azure-dotnet-azure-function-apps.yml`
- `CONFIGURATION-GUIDE.md`

### Example 2: Python App Service on AKS

**Input:**
- Application Type: Azure App Service
- Language: Python
- Deployment Type: AKS
- Project Name: python-web-app

**Output:**
- `ci-python-azure-app-service.yml`
- `cd-aks-python-azure-app-service.yml`
- `CONFIGURATION-GUIDE.md`

### Example 3: Node.js API on IIS

**Input:**
- Application Type: Azure API Management
- Language: Node
- Deployment Type: IIS
- Project Name: node-api

**Output:**
- `ci-node-azure-api-management.yml`
- `cd-iis-node-azure-api-management.yml`
- `CONFIGURATION-GUIDE.md`

## 🔐 Security Best Practices

1. **Never commit secrets**: Always use GitHub Secrets
2. **Use API tokens**: Prefer tokens over passwords for service authentication
3. **Environment protection**: Configure GitHub Environment protection rules
4. **Branch protection**: Require reviews for production deployments
5. **Secret rotation**: Regularly rotate credentials and tokens
6. **Least privilege**: Grant minimum required permissions to service accounts

## 🐛 Troubleshooting

### Template Generation Fails

- Verify PowerShell scripts have correct line endings (LF, not CRLF)
- Check that all required inputs are provided
- Review workflow logs for specific error messages

### CI Pipeline Issues

- Verify SDK versions match your project requirements
- Check that dependency sources are accessible
- Ensure JFrog credentials are correct

### CD Pipeline Issues

- Verify all deployment secrets are configured
- Check network connectivity to deployment targets
- Review deployment logs for authentication errors

### Common Error Messages

**"JFrog CLI not found"**
- The workflow will automatically install JFrog CLI
- If issues persist, check network connectivity

**"Azure login failed"**
- Verify service principal credentials
- Check that subscription ID is correct
- Ensure service principal has required permissions

**"Kubectl connection refused"**
- Verify AKS cluster name and resource group
- Check that AKS cluster is running
- Ensure service principal has AKS access

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [JFrog Artifactory Documentation](https://www.jfrog.com/confluence/display/JFROG/JFrog+Artifactory)
- [Azure DevOps Best Practices](https://docs.microsoft.com/en-us/azure/devops/)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [IIS Deployment Guide](https://docs.microsoft.com/en-us/iis/)

## 🤝 Contributing

To extend this template generator:

1. Add new application types in the workflow inputs
2. Implement corresponding template functions in `template-functions.ps1`
3. Add deployment logic for new target environments
4. Update documentation with new options

## 📝 License

This template generator is provided as-is for use in your projects. Customize as needed for your organization's requirements.

## 💡 Tips

- **Start with development**: Always test in development environment first
- **Review generated templates**: Customize templates before using in production
- **Keep templates updated**: Regularly update SDK versions and dependencies
- **Monitor deployments**: Set up monitoring and alerting for production deployments
- **Document changes**: Keep track of customizations you make to templates

## 🆘 Support

For issues or questions:

1. Check the generated `CONFIGURATION-GUIDE.md` for specific guidance
2. Review the extensive comments in generated templates
3. Consult the troubleshooting section above
4. Review GitHub Actions logs for detailed error messages

---

**Made with ❤️ for DevOps automation**

*Generated templates include comprehensive comments and are designed to be production-ready with minimal customization.*
