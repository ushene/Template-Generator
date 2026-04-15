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
Write-Host "      [OK] Reusable CI workflow created: $reusableCIPath" -ForegroundColor Green

# Generate Reusable CD Workflow
Write-Host "[2/6] Generating reusable CD workflow..." -ForegroundColor Yellow
$reusableCDTemplate = Get-ReusableCDWorkflow -DeploymentType $DeploymentType
$reusableCDPath = "$workflowsDir/reusable-cd-$deploySlug.yml"
Set-Content -Path $reusableCDPath -Value $reusableCDTemplate -Encoding UTF8
Write-Host "      [OK] Reusable CD workflow created: $reusableCDPath" -ForegroundColor Green

# Generate Main Build Workflow (Orchestrator)
Write-Host "[3/6] Generating main build workflow (orchestrator)..." -ForegroundColor Yellow
$mainBuildTemplate = Get-MainBuildWorkflow -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$mainBuildPath = "$workflowsDir/build.yml"
Set-Content -Path $mainBuildPath -Value $mainBuildTemplate -Encoding UTF8
Write-Host "      [OK] Main build workflow created: $mainBuildPath" -ForegroundColor Green

# Generate Legacy Templates (for backward compatibility)
Write-Host "[4/6] Generating legacy CI template..." -ForegroundColor Yellow
$ciTemplate = Get-CITemplate -ApplicationType $ApplicationType -Language $Language -ProjectName $ProjectName
$ciFilePath = "$workflowsDir/ci-legacy-$langSlug-$appTypeSlug.yml"
Set-Content -Path $ciFilePath -Value $ciTemplate -Encoding UTF8
Write-Host "      [OK] Legacy CI template created: $ciFilePath" -ForegroundColor Green

Write-Host "[5/6] Generating legacy CD template..." -ForegroundColor Yellow
$cdTemplate = Get-CDTemplate -ApplicationType $ApplicationType -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$cdFilePath = "$workflowsDir/cd-legacy-$deploySlug-$langSlug-$appTypeSlug.yml"
Set-Content -Path $cdFilePath -Value $cdTemplate -Encoding UTF8
Write-Host "      [OK] Legacy CD template created: $cdFilePath" -ForegroundColor Green

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host " GENERATING DOCUMENTATION" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green

# Generate Azure DevOps Migration Guide
Write-Host "[6/6] Generating Azure DevOps migration guide..." -ForegroundColor Yellow
$migrationGuide = Get-AzureDevOpsMigrationGuide -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$migrationGuidePath = "$outputDir/AZURE-DEVOPS-MIGRATION-GUIDE.md"
Set-Content -Path $migrationGuidePath -Value $migrationGuide -Encoding UTF8
Write-Host "      [OK] Migration guide created: $migrationGuidePath" -ForegroundColor Green

# Generate Configuration Guide
$configGuide = Get-ConfigurationGuide -ApplicationType $ApplicationType -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$guideFilePath = "$outputDir/CONFIGURATION-GUIDE.md"
Set-Content -Path $guideFilePath -Value $configGuide -Encoding UTF8
Write-Host "      [OK] Configuration guide created: $guideFilePath" -ForegroundColor Green

# Create README for the generated folder
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$readmeLines = @(
    "# Generated GitHub Actions Workflows for $ProjectName",
    "",
    "This folder contains GitHub Actions workflows generated for your project.",
    "",
    "## Folder Structure",
    "",
    "    .github/workflows/",
    "        build.yml - Main orchestrator workflow - USE THIS",
    "        reusable-ci-$langSlug.yml - Reusable CI workflow",
    "        reusable-cd-$deploySlug.yml - Reusable CD workflow",
    "        ci-legacy-*.yml - Legacy CI template",
    "        cd-legacy-*.yml - Legacy CD template",
    "",
    "## Quick Start",
    "",
    "### Option 1: Reusable Workflows - Recommended",
    "",
    "1. Copy the generated .github folder to your repository root",
    "2. Configure GitHub Secrets in repository settings",
    "   Required: JFROG_URL, JFROG_USERNAME, JFROG_PASSWORD",
    "   See CONFIGURATION-GUIDE.md for complete list",
    "3. Create GitHub Environments: development, staging, production",
    "4. Push code to trigger workflows",
    "",
    "### Option 2: Legacy Templates",
    "",
    "Use ci-legacy and cd-legacy files for traditional separate CI/CD workflows.",
    "",
    "## Documentation",
    "",
    "- CONFIGURATION-GUIDE.md: Setup instructions and secrets",
    "- AZURE-DEVOPS-MIGRATION-GUIDE.md: Migration guide from Azure DevOps",
    "",
    "## Workflow Features",
    "",
    "- Main Build Workflow: Orchestrates CI/CD using reusable workflows",
    "- Reusable CI: Build, test, scan, package, publish to JFrog",
    "- Reusable CD: Download from JFrog, deploy, health check",
    "",
    "## Azure DevOps Migration",
    "",
    "Read AZURE-DEVOPS-MIGRATION-GUIDE.md for complete migration steps.",
    "",
    "## Support",
    "",
    "Review configuration guides or check GitHub Actions documentation.",
    "",
    "---",
    "Generated: $timestamp",
    "Version: 2.0 - Reusable Workflows"
)
$readmeContent = $readmeLines -join "`n"

$readmePath = "$outputDir/README.md"
Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
Write-Host "      [OK] README created: $readmePath" -ForegroundColor Green

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
