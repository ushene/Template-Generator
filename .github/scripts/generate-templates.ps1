#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Template Generator Script for CI/CD Pipelines

.DESCRIPTION
    This script generates CI and CD YAML templates based on the application type,
    programming language, and deployment target. Templates are created with
    parameterized values and comprehensive comments.

.PARAMETER ApplicationType
    The type of Azure application (Function Apps, App Service, Container Apps, etc.)

.PARAMETER Language
    The programming language (.NET, Python, Node)

.PARAMETER DeploymentType
    The deployment target (IIS, AKS, Azure)

.PARAMETER ProjectName
    The name of the project for generated file naming

.EXAMPLE
    .\generate-templates.ps1 -ApplicationType "Azure Function Apps" -Language ".NET" -DeploymentType "Azure" -ProjectName "my-app"
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

# Create output directory
$outputDir = "generated"
if (Test-Path $outputDir) {
    Remove-Item -Path $outputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Write-Host "`n=== Starting Template Generation ===" -ForegroundColor Green
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

# Generate CI Template
Write-Host "Generating CI template..." -ForegroundColor Yellow
$ciTemplate = Get-CITemplate -ApplicationType $ApplicationType -Language $Language -ProjectName $ProjectName
$ciFilePath = "$outputDir/ci-$langSlug-$appTypeSlug.yml"
Set-Content -Path $ciFilePath -Value $ciTemplate -Encoding UTF8
Write-Host "✓ CI template created: $ciFilePath" -ForegroundColor Green

# Generate CD Template
Write-Host "Generating CD template..." -ForegroundColor Yellow
$cdTemplate = Get-CDTemplate -ApplicationType $ApplicationType -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$cdFilePath = "$outputDir/cd-$deploySlug-$langSlug-$appTypeSlug.yml"
Set-Content -Path $cdFilePath -Value $cdTemplate -Encoding UTF8
Write-Host "✓ CD template created: $cdFilePath" -ForegroundColor Green

# Generate Configuration Guide
Write-Host "Generating configuration guide..." -ForegroundColor Yellow
$configGuide = Get-ConfigurationGuide -ApplicationType $ApplicationType -Language $Language -DeploymentType $DeploymentType -ProjectName $ProjectName
$guideFilePath = "$outputDir/CONFIGURATION-GUIDE.md"
Set-Content -Path $guideFilePath -Value $configGuide -Encoding UTF8
Write-Host "✓ Configuration guide created: $guideFilePath" -ForegroundColor Green

Write-Host "`n=== Template Generation Complete ===" -ForegroundColor Green
Write-Host "All files generated in: $outputDir/" -ForegroundColor Cyan
