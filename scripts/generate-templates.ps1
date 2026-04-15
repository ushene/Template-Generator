#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Template Generator Script for CI/CD Pipelines

.DESCRIPTION
    This script generates CI and CD YAML templates based on the application type,
    programming language, and deployment target. Templates are created with
    parameterized values and comprehensive comments. Now includes reusable workflows!

.PARAMETER ApplicationType
    The type of Azure application (Function Apps, App Service, Container Apps, etc.)

.PARAMETER Language
    The programming language (.NET, Python, Node)

.PARAMETER DeploymentType
    The deployment target (IIS, AKS, Azure)

.PARAMETER ProjectName
    The name of the project for generated file naming

.EXAMPLE
    .\generate-templates.ps1 -ApplicationType "Azure App Service" -Language ".NET" -DeploymentType "Azure" -ProjectName "my-app"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ApplicationType,
    
    [Parameter(Mandatory=$true)]
    [string]$Language,
    
    [Parameter(Mandatory=$true)]
    [string]$DeploymentType,
    
    [Parameter(Mandatory=$true)]
    [string]$ProjectName
)

# Create output directory structure
$outputDir = "generated"
$workflowsDir = "$outputDir/.github/workflows"

if (Test-Path $outputDir) {
    Remove-Item -Path $outputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  GitHub Actions Template Generator with Reusable Workflows   " -ForegroundColor Cyan
Write-Host "  & Azure DevOps Migration Support                             " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application Type: $ApplicationType" -ForegroundColor Cyan
Write-Host "Language: $Language" -ForegroundColor Cyan
Write-Host "Deployment Type: $DeploymentType" -ForegroundColor Cyan
Write-Host "Project Name: $ProjectName`n" -ForegroundColor Cyan

# Normalize inputs for file naming
$appTypeSlug = $ApplicationType -replace '\s+', '-' -replace '&', 'and' | ForEach-Object { $_.ToLower() }
$langSlug = $Language -replace '\.', '' | ForEach-Object { $_.ToLower() }
$deploySlug = $DeploymentType.ToLower()

# Load template functions
. "$PSScriptRoot/template-functions.ps1"
. "$PSScriptRoot/reusable-workflow-functions.ps1"

Write-Host "===============================================================" -ForegroundColor Green
Write-Host " GENERATING REUSABLE WORKFLOWS" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green

# Generate Reusable CI Workflow
Write-Host "[1/6] Generating reusable CI workflow..." -ForegroundColor Yellow
$reusableCITemplate = Get-ReusableCIWorkflow -Language $Language
$reusableCIPath = "$workflowsDir/reusable-ci-$langSlug.yml"
Set-Content -Path $reusableCIPath -Value $reusableCITemplate -Encoding UTF8
Write-Host "      ✓ Reusable CI workflow created: $reusableCIPath" -ForegroundColor Green

# Generate Reusable CD Workflow
Write-Host "[2/6] Generating reusable CD workflow..." -ForegroundColor Yellow
$reusableCDTemplate = Get-ReusableCDWorkflow -DeploymentType $DeploymentType
$reusableCDPath = "$workflowsDir/reusable-cd-$deploySlug.yml"
Set-Content -Path $reusableCDPath -Value $reusableCDTemplate -Encoding UTF8
Write-Host "      ✓ Reusable CD workflow created: $reusableCDPath" -ForegroundColor Green

# Generate Main Build Workflow (Orchestrator)
Write-Host "[3/6] Generating main build workflow (orchestrator)..." -ForegroundColor Yellow
$mainBuildTemplate = Get-MainBuildWorkflow -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$mainBuildPath = "$workflowsDir/build.yml"
Set-Content -Path $mainBuildPath -Value $mainBuildTemplate -Encoding UTF8
Write-Host "      ✓ Main build workflow created: $mainBuildPath" -ForegroundColor Green

# Generate Legacy Templates (for backward compatibility)
Write-Host "[4/6] Generating legacy CI template..." -ForegroundColor Yellow
$ciTemplate = Get-CITemplate -ApplicationType $ApplicationType -Language $Language -ProjectName $ProjectName
$ciFilePath = "$workflowsDir/ci-legacy-$langSlug-$appTypeSlug.yml"
Set-Content -Path $ciFilePath -Value $ciTemplate -Encoding UTF8
Write-Host "      ✓ Legacy CI template created: $ciFilePath" -ForegroundColor Green

Write-Host "[5/6] Generating legacy CD template..." -ForegroundColor Yellow
$cdTemplate = Get-CDTemplate -ApplicationType $ApplicationType -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$cdFilePath = "$workflowsDir/cd-legacy-$deploySlug-$langSlug-$appTypeSlug.yml"
Set-Content -Path $cdFilePath -Value $cdTemplate -Encoding UTF8
Write-Host "      ✓ Legacy CD template created: $cdFilePath" -ForegroundColor Green

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host " GENERATING DOCUMENTATION" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green

# Generate Azure DevOps Migration Guide
Write-Host "[6/6] Generating Azure DevOps migration guide..." -ForegroundColor Yellow
$migrationGuide = Get-AzureDevOpsMigrationGuide -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$migrationGuidePath = "$outputDir/AZURE-DEVOPS-MIGRATION-GUIDE.md"
Set-Content -Path $migrationGuidePath -Value $migrationGuide -Encoding UTF8
Write-Host "      ✓ Migration guide created: $migrationGuidePath" -ForegroundColor Green

# Generate Configuration Guide
$configGuide = Get-ConfigurationGuide -ApplicationType $ApplicationType -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$guideFilePath = "$outputDir/CONFIGURATION-GUIDE.md"
Set-Content -Path $guideFilePath -Value $configGuide -Encoding UTF8
Write-Host "      ✓ Configuration guide created: $guideFilePath" -ForegroundColor Green

# Create README for the generated folder
$readmeContent = @"
# Generated GitHub Actions Workflows for $ProjectName

This folder contains GitHub Actions workflows generated for your project.

## 📁 Folder Structure

\`\`\`
.github/
└── workflows/
    ├── build.yml                        # 🎯 MAIN orchestrator workflow (USE THIS!)
    ├── reusable-ci-$langSlug.yml              # 🔧 Reusable CI workflow
    ├── reusable-cd-$deploySlug.yml           # 🚀 Reusable CD workflow
    ├── ci-legacy-$langSlug-$appTypeSlug.yml  # 📦 Legacy CI (for reference)
    └── cd-legacy-$deploySlug-$langSlug-$appTypeSlug.yml  # 📦 Legacy CD (for reference)
\`\`\`

## 🚀 Quick Start

### Option 1: Use Reusable Workflows (Recommended)

1. **Copy the generated \`.github/workflows/\` folder to your repository root**
   \`\`\`bash
   cp -r generated/.github .
   \`\`\`

2. **Configure GitHub Secrets** (Settings > Secrets and variables > Actions):
   - \`JFROG_URL\`
   - \`JFROG_USERNAME\`
   - \`JFROG_PASSWORD\`
   - Additional secrets based on deployment type (see CONFIGURATION-GUIDE.md)

3. **Create GitHub Environments** (Settings > Environments):
   - Create: \`development\`, \`staging\`, \`production\`
   - Add environment-specific variables (see AZURE-DEVOPS-MIGRATION-GUIDE.md)

4. **Push to trigger the workflow**:
   - Push to \`develop\` → Deploys to development
   - Push to \`main\` → Deploys to staging
   - Manual trigger with 'production' → Deploys to production

### Option 2: Use Legacy Templates

If you prefer traditional separate CI/CD workflows:
- Use \`ci-legacy-*.yml\` for continuous integration
- Use \`cd-legacy-*.yml\` for deployment

## 📖 Documentation

- **[CONFIGURATION-GUIDE.md](./CONFIGURATION-GUIDE.md)**: Setup instructions and secrets configuration
- **[AZURE-DEVOPS-MIGRATION-GUIDE.md](./AZURE-DEVOPS-MIGRATION-GUIDE.md)**: Complete migration guide from Azure DevOps

## 🎯 Workflow Features

### Main Build Workflow (\`build.yml\`)
- Orchestrates CI/CD using reusable workflows
- Automatic deployment to dev (on \`develop\` branch)
- Automatic deployment to staging (on \`main\` branch)
- Manual deployment to production
- Calls reusable CI and CD workflows

### Reusable CI Workflow (\`reusable-ci-*.yml\`)
- ✅ Build and compile
- ✅ Run unit tests
- ✅ Security scanning (SonarQube, Snyk)
- ✅ Package artifacts
- ✅ Publish to JFrog Artifactory
- ✅ Upload to GitHub artifacts
- ✅ Returns version and status outputs

### Reusable CD Workflow (\`reusable-cd-*.yml\`)
- ✅ Download artifacts from JFrog
- ✅ Deploy to target environment
- ✅ Health checks
- ✅ Smoke tests
- ✅ Returns deployment URL and status

## 🔄 Azure DevOps Migration

If you're migrating from Azure DevOps:

1. Read **AZURE-DEVOPS-MIGRATION-GUIDE.md**
2. Export your service connections → Create GitHub secrets
3. Export variable groups → Create GitHub environments
4. Map pipeline stages → Use reusable workflows
5. Test thoroughly before go-live

## 🛠 Customization

### Modify Build Configuration
Edit \`reusable-ci-*.yml\`:
- Change SDK/runtime versions
- Modify test commands
- Adjust security scanning

### Modify Deployment
Edit \`reusable-cd-*.yml\`:
- Customize deployment steps
- Adjust health check endpoints
- Modify rollback procedures

### Add New Environments
1. Create environment in GitHub Settings
2. Add environment variables
3. Update \`build.yml\` to add deployment job

## 📝 Notes

- **Reusable workflows** are the recommended approach for maintainability
- **Legacy templates** are provided for backward compatibility
- **Environment protection rules** should be configured in GitHub Settings
- **Secrets** must be configured before workflows can run

## ⚠️ Important

Before deploying to production:
1. Test in development environment
2. Verify all secrets are configured
3. Configure environment protection rules
4. Set up required approvals for production

## 📞 Support

For issues or questions:
1. Review the configuration guides
2. Check GitHub Actions documentation
3. Contact your DevOps team

---

Generated on: `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Template Version: 2.0 (Reusable Workflows)
"@

$readmePath = "$outputDir/README.md"
Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
Write-Host "      ✓ README created: $readmePath" -ForegroundColor Green

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "      [SUCCESS] TEMPLATE GENERATION COMPLETE" -ForegroundColor Green  
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[*] Generated files structure:" -ForegroundColor Cyan
Write-Host "   $outputDir/" -ForegroundColor White
Write-Host "   +-- .github/" -ForegroundColor White
Write-Host "       +-- workflows/" -ForegroundColor White
Write-Host "           +-- build.yml                    (Main orchestrator)" -ForegroundColor Yellow
Write-Host "           +-- reusable-ci-$langSlug.yml      (Reusable CI)" -ForegroundColor Yellow
Write-Host "           +-- reusable-cd-$deploySlug.yml   (Reusable CD)" -ForegroundColor Yellow
Write-Host "           +-- ci-legacy-*.yml              (Legacy CI)" -ForegroundColor DarkGray
Write-Host "           +-- cd-legacy-*.yml              (Legacy CD)" -ForegroundColor DarkGray
Write-Host "   +-- README.md                          (Quick start guide)" -ForegroundColor Cyan
Write-Host "   +-- CONFIGURATION-GUIDE.md             (Setup instructions)" -ForegroundColor Cyan
Write-Host "   +-- AZURE-DEVOPS-MIGRATION-GUIDE.md    (Migration guide)" -ForegroundColor Cyan
Write-Host ""
Write-Host "[*] Next Steps:" -ForegroundColor Green
Write-Host "   1. Copy generated/.github folder to your repository root" -ForegroundColor White
Write-Host "   2. Configure GitHub Secrets (see CONFIGURATION-GUIDE.md)" -ForegroundColor White
Write-Host "   3. Create GitHub Environments (development, staging, production)" -ForegroundColor White
Write-Host "   4. Push code to trigger the workflow" -ForegroundColor White
Write-Host ""
Write-Host "[*] For Azure DevOps migration:" -ForegroundColor Yellow
Write-Host "   Read AZURE-DEVOPS-MIGRATION-GUIDE.md for complete migration steps" -ForegroundColor White
Write-Host ""
