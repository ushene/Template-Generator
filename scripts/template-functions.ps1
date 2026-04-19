#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Template Functions for CI/CD Pipeline Generation

.DESCRIPTION
    This module contains functions to generate CI and CD templates
    for various Azure services, programming languages, and deployment targets.
#>

function Get-CITemplate {
    param(
        [string]$ApplicationType,
        [string]$Language,
        [string]$ProjectName
    )
    
    $buildSteps = Get-BuildSteps -Language $Language -ApplicationType $ApplicationType
    $testSteps = Get-TestSteps -Language $Language
    $scanSteps = Get-ScanSteps -Language $Language
    
    $template = @"
# CI Pipeline Template
# Generated for: $ApplicationType ($Language)
# Project: $ProjectName
# Description: Build, test, scan, and publish artifacts to JFrog

name: CI - Build and Test

on:
  push:
    branches:
      # Configure branches that should trigger CI builds
      - main
      - develop
      - 'feature/**'
  pull_request:
    branches:
      - main
      - develop
  workflow_dispatch:
    inputs:
      skip_tests:
        description: 'Skip running tests'
        required: false
        type: boolean
        default: false

# Environment variables - customize these for your project
env:
  # Build configuration
  BUILD_CONFIGURATION: 'Release'
  
  # JFrog Artifactory settings
  JFROG_URL: `${{ secrets.JFROG_URL }}               # JFrog Artifactory URL
  JFROG_REPOSITORY: `${{ secrets.JFROG_REPOSITORY }} # Target repository name
  JFROG_USERNAME: `${{ secrets.JFROG_USERNAME }}     # JFrog username
  JFROG_PASSWORD: `${{ secrets.JFROG_PASSWORD }}     # JFrog password or API token
  
  # Application-specific settings
  APP_NAME: '$ProjectName'
  APP_VERSION: `${{ github.run_number }}
  
  # Security scanning settings
  SONAR_TOKEN: `${{ secrets.SONAR_TOKEN }}           # SonarQube token for code analysis
  SNYK_TOKEN: `${{ secrets.SNYK_TOKEN }}             # Snyk token for vulnerability scanning

jobs:
  build:
    name: Build and Test
    runs-on: ubuntu-latest
    
    steps:
      # Step 1: Checkout source code
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Fetch all history for better analysis
      
      # Step 2: Setup build environment
$buildSteps
      
      # Step 3: Restore dependencies
      - name: Restore dependencies
        shell: pwsh
        run: |
          Write-Host "Restoring project dependencies..." -ForegroundColor Cyan
$( Get-RestoreCommand -Language $Language )
      
      # Step 4: Build application
      - name: Build application
        shell: pwsh
        run: |
          Write-Host "Building application in `$env:BUILD_CONFIGURATION mode..." -ForegroundColor Cyan
$( Get-BuildCommand -Language $Language )
      
      # Step 5: Run unit tests
$testSteps
      
      # Step 6: Code quality and security scanning
$scanSteps
      
      # Step 7: Package application
      - name: Package application
        shell: pwsh
        run: |
          Write-Host "Packaging application..." -ForegroundColor Cyan
          `$packageName = "`$env:APP_NAME-`$env:APP_VERSION"
          
$( Get-PackageCommand -Language $Language -ApplicationType $ApplicationType )
      
      # Step 8: Publish to JFrog Artifactory
      - name: Publish to JFrog
        shell: pwsh
        run: |
          Write-Host "Publishing artifacts to JFrog Artifactory..." -ForegroundColor Cyan
          
          # Setup JFrog CLI (if not already available)
          if (-not (Get-Command jfrog -ErrorAction SilentlyContinue)) {
            Write-Host "Installing JFrog CLI..." -ForegroundColor Yellow
            curl -fL https://install-cli.jfrog.io | sh
            sudo mv jfrog /usr/local/bin/
          }
          
          # Configure JFrog CLI
          jfrog config add artifactory --url="`$env:JFROG_URL" --user="`$env:JFROG_USERNAME" --password="`$env:JFROG_PASSWORD" --interactive=false
          
          # Upload artifacts
          `$artifactPath = "artifacts/*"
          `$targetPath = "`$env:JFROG_REPOSITORY/`$env:APP_NAME/`$env:APP_VERSION/"
          
          Write-Host "Uploading from `$artifactPath to `$targetPath" -ForegroundColor Cyan
          jfrog rt upload "`$artifactPath" "`$targetPath" --flat=false --recursive=true
          
          Write-Host "✓ Artifacts published successfully" -ForegroundColor Green
      
      # Step 9: Upload build artifacts (backup)
      - name: Upload artifacts to GitHub
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts-`${{ github.run_number }}
          path: artifacts/
          retention-days: 30
      
      # Step 10: Build summary
      - name: Build summary
        if: always()
        shell: pwsh
        run: |
          Write-Host "`n=== Build Summary ===" -ForegroundColor Green
          Write-Host "Application: `$env:APP_NAME" -ForegroundColor Cyan
          Write-Host "Version: `$env:APP_VERSION" -ForegroundColor Cyan
          Write-Host "Configuration: `$env:BUILD_CONFIGURATION" -ForegroundColor Cyan
          Write-Host "Build Status: `${{ job.status }}" -ForegroundColor Cyan
          Write-Host "========================`n" -ForegroundColor Green
"@
    
    return $template
}

function Get-CDTemplate {
    param(
        [string]$ApplicationType,
        [string]$Language,
        [string]$DeploymentType,
        [string]$ProjectName
    )
    
    $deploymentSteps = Get-DeploymentSteps -ApplicationType $ApplicationType -Language $Language -DeploymentType $DeploymentType
    $preDeploySteps = Get-PreDeploymentSteps -DeploymentType $DeploymentType
    $postDeploySteps = Get-PostDeploymentSteps -DeploymentType $DeploymentType -ApplicationType $ApplicationType
    
    $template = @"
# CD Pipeline Template
# Generated for: $ApplicationType ($Language) -> $DeploymentType
# Project: $ProjectName
# Description: Deploy application to $DeploymentType

name: CD - Deploy to $DeploymentType

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target Environment'
        required: true
        type: choice
        options:
          - development
          - staging
          - production
      version:
        description: 'Version to deploy (build number or tag)'
        required: true
        type: string
      skip_health_check:
        description: 'Skip post-deployment health check'
        required: false
        type: boolean
        default: false

# Environment variables - customize these for your project
env:
  # Application settings
  APP_NAME: '$ProjectName'
  APP_VERSION: `${{ inputs.version }}
  TARGET_ENV: `${{ inputs.environment }}
  
  # JFrog Artifactory settings
  JFROG_URL: `${{ secrets.JFROG_URL }}
  JFROG_REPOSITORY: `${{ secrets.JFROG_REPOSITORY }}
  JFROG_USERNAME: `${{ secrets.JFROG_USERNAME }}
  JFROG_PASSWORD: `${{ secrets.JFROG_PASSWORD }}

# Deployment jobs with environment-specific configuration
jobs:
  deploy:
    name: Deploy to `${{ inputs.environment }}
    runs-on: $( if ($DeploymentType -eq 'IIS') { 'windows-latest' } else { 'ubuntu-latest' } )
    
    # Configure environment protection rules
    environment:
      name: `${{ inputs.environment }}
      url: `${{ steps.deploy.outputs.app_url }}
    
    steps:
      # Step 1: Checkout repository (for scripts and configurations)
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          sparse-checkout: |
            deployment/
            scripts/
      
      # Step 2: Download artifacts from JFrog
      - name: Download artifacts from JFrog
        shell: $( if ($DeploymentType -eq 'IIS') { 'pwsh' } else { 'pwsh' } )
        run: |
          Write-Host "Downloading artifacts from JFrog Artifactory..." -ForegroundColor Cyan
          
          # Install JFrog CLI if not present
          if (-not (Get-Command jfrog -ErrorAction SilentlyContinue)) {
            Write-Host "Installing JFrog CLI..." -ForegroundColor Yellow
$( if ($DeploymentType -eq 'IIS') {
    '            Invoke-WebRequest -Uri "https://releases.jfrog.io/artifactory/jfrog-cli/v2/[RELEASE]/jfrog-cli-windows-amd64/jfrog.exe" -OutFile "jfrog.exe"' + "`n" +
    '            $env:PATH += ";$(Get-Location)"'
} else {
    '            curl -fL https://install-cli.jfrog.io | sh' + "`n" +
    '            sudo mv jfrog /usr/local/bin/'
} )
          }
          
          # Configure JFrog CLI
          jfrog config add artifactory --url="`$env:JFROG_URL" --user="`$env:JFROG_USERNAME" --password="`$env:JFROG_PASSWORD" --interactive=false
          
          # Download artifacts
          `$artifactPath = "`$env:JFROG_REPOSITORY/`$env:APP_NAME/`$env:APP_VERSION/"
          `$downloadDir = "artifacts"
          
          New-Item -ItemType Directory -Path `$downloadDir -Force | Out-Null
          Write-Host "Downloading from `$artifactPath to `$downloadDir" -ForegroundColor Cyan
          jfrog rt download "`$artifactPath" "`$downloadDir/" --flat=false --recursive=true
          
          Write-Host "✓ Artifacts downloaded successfully" -ForegroundColor Green
      
      # Step 3: Pre-deployment validation and setup
$preDeploySteps
      
      # Step 4: Deploy application
$deploymentSteps
      
      # Step 5: Post-deployment verification
$postDeploySteps
      
      # Step 6: Deployment summary
      - name: Deployment summary
        if: always()
        shell: pwsh
        run: |
          Write-Host "`n=== Deployment Summary ===" -ForegroundColor Green
          Write-Host "Application: `$env:APP_NAME" -ForegroundColor Cyan
          Write-Host "Version: `$env:APP_VERSION" -ForegroundColor Cyan
          Write-Host "Environment: `$env:TARGET_ENV" -ForegroundColor Cyan
          Write-Host "Deployment Type: $DeploymentType" -ForegroundColor Cyan
          Write-Host "Status: `${{ job.status }}" -ForegroundColor Cyan
          Write-Host "===========================`n" -ForegroundColor Green

  # Rollback job (manual trigger only)
  rollback:
    name: Rollback deployment
    runs-on: $( if ($DeploymentType -eq 'IIS') { 'windows-latest' } else { 'ubuntu-latest' } )
    if: failure() && github.event_name == 'workflow_dispatch'
    needs: deploy
    
    steps:
      - name: Trigger rollback
        shell: pwsh
        run: |
          Write-Host "⚠️  Deployment failed - initiating rollback procedure..." -ForegroundColor Red
          Write-Host "Please review the deployment logs and trigger rollback manually if needed." -ForegroundColor Yellow
          
          # Add rollback logic here based on your deployment strategy
          # This could involve:
          # - Deploying previous version
          # - Restoring database backup
          # - Rolling back infrastructure changes
"@
    
    return $template
}

function Get-BuildSteps {
    param([string]$Language, [string]$ApplicationType)
    
    switch ($Language) {
        '.NET' {
            return @"
      - name: Setup .NET SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.x'  # Specify your .NET version
      
      - name: Display .NET version
        shell: pwsh
        run: |
          Write-Host ".NET SDK Version:" -ForegroundColor Cyan
          dotnet --version
"@
        }
        'Python' {
            return @"
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'  # Specify your Python version
      
      - name: Display Python version
        shell: pwsh
        run: |
          Write-Host "Python Version:" -ForegroundColor Cyan
          python --version
          pip --version
"@
        }
        'Node' {
            return @"
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'  # Specify your Node.js version
          cache: 'npm'
      
      - name: Display Node version
        shell: pwsh
        run: |
          Write-Host "Node.js Version:" -ForegroundColor Cyan
          node --version
          npm --version
"@
        }
    }
}

function Get-RestoreCommand {
    param([string]$Language)
    
    switch ($Language) {
        '.NET' {
            return '          dotnet restore'
        }
        'Python' {
            return @'
          if (Test-Path "requirements.txt") {
            pip install -r requirements.txt
          }
'@
        }
        'Node' {
            return '          npm ci'
        }
    }
}

function Get-BuildCommand {
    param([string]$Language)
    
    switch ($Language) {
        '.NET' {
            return '          dotnet build --configuration $env:BUILD_CONFIGURATION --no-restore'
        }
        'Python' {
            return @'
          # Python projects may not require a build step
          # Add any compilation or preparation steps here
          Write-Host "Python project - skipping build step" -ForegroundColor Yellow
'@
        }
        'Node' {
            return @'
          npm run build
          # Or use: npm run compile if you have TypeScript
'@
        }
    }
}

function Get-TestSteps {
    param([string]$Language)
    
    switch ($Language) {
        '.NET' {
            return @"
      - name: Run unit tests
        if: `${{ !inputs.skip_tests }}
        shell: pwsh
        run: |
          Write-Host "Running unit tests..." -ForegroundColor Cyan
          dotnet test --no-build --configuration `$env:BUILD_CONFIGURATION --logger "trx;LogFileName=test-results.trx" --collect:"XPlat Code Coverage"
      
      - name: Publish test results
        if: always() && !inputs.skip_tests
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: '**/test-results.trx'
"@
        }
        'Python' {
            return @"
      - name: Run unit tests
        if: `${{ !inputs.skip_tests }}
        shell: pwsh
        run: |
          Write-Host "Running unit tests with pytest..." -ForegroundColor Cyan
          pip install pytest pytest-cov
          pytest --cov=. --cov-report=xml --cov-report=html
      
      - name: Publish test results
        if: always() && !inputs.skip_tests
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: |
            coverage.xml
            htmlcov/
"@
        }
        'Node' {
            return @"
      - name: Run unit tests
        if: `${{ !inputs.skip_tests }}
        shell: pwsh
        run: |
          Write-Host "Running unit tests..." -ForegroundColor Cyan
          npm test -- --coverage --ci
      
      - name: Publish test results
        if: always() && !inputs.skip_tests
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: coverage/
"@
        }
    }
}

function Get-ScanSteps {
    param([string]$Language)
    
    return @"
      - name: Run SonarQube analysis
        if: env.SONAR_TOKEN != ''
        shell: pwsh
        run: |
          Write-Host "Running SonarQube code quality analysis..." -ForegroundColor Cyan
          # Install SonarScanner if needed
          # Configure and run based on your SonarQube setup
          Write-Host "SonarQube analysis configured - implement based on your setup" -ForegroundColor Yellow
      
      - name: Setup Node for Snyk
        if: env.SNYK_TOKEN != ''
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Run Snyk security scan
        if: env.SNYK_TOKEN != ''
        shell: pwsh
        run: |
          Write-Host "Running Snyk security vulnerability scan..." -ForegroundColor Cyan
          npm install -g snyk
          snyk auth `$env:SNYK_TOKEN
          snyk test --severity-threshold=high || true
          snyk monitor
"@
}

function Get-PackageCommand {
    param([string]$Language, [string]$ApplicationType)
    
    switch ($Language) {
        '.NET' {
            if ($ApplicationType -like '*Function*') {
                return @'
          # Package Azure Function App
          $publishDir = "publish"
          dotnet publish --configuration $env:BUILD_CONFIGURATION --output $publishDir --no-build
          
          # Create deployment package
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          Compress-Archive -Path "$publishDir\*" -DestinationPath "artifacts\$packageName.zip"
          Write-Host "✓ Package created: artifacts\$packageName.zip" -ForegroundColor Green
'@
            } else {
                return @'
          # Package application
          $publishDir = "publish"
          dotnet publish --configuration $env:BUILD_CONFIGURATION --output $publishDir --no-build
          
          # Create deployment package
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          Compress-Archive -Path "$publishDir\*" -DestinationPath "artifacts\$packageName.zip"
          Write-Host "✓ Package created: artifacts\$packageName.zip" -ForegroundColor Green
'@
            }
        }
        'Python' {
            return @'
          # Package Python application
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          
          # Create a deployment package with all source and dependencies
          if (Test-Path "requirements.txt") {
            pip install -r requirements.txt -t artifacts/
          }
          
          # Copy application code
          Copy-Item -Path "*.py" -Destination "artifacts/" -Recurse -Force
          if (Test-Path "app/") { Copy-Item -Path "app/" -Destination "artifacts/app/" -Recurse -Force }
          
          # Create zip package
          Compress-Archive -Path "artifacts\*" -DestinationPath "artifacts\$packageName.zip"
          Write-Host "✓ Package created: artifacts\$packageName.zip" -ForegroundColor Green
'@
        }
        'Node' {
            return @'
          # Package Node.js application
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          
          # Create deployment package
          $packageFiles = @(
            "package.json",
            "package-lock.json",
            "dist/",
            "build/",
            "node_modules/"
          )
          
          foreach ($file in $packageFiles) {
            if (Test-Path $file) {
              Copy-Item -Path $file -Destination "artifacts/" -Recurse -Force
            }
          }
          
          Compress-Archive -Path "artifacts\*" -DestinationPath "artifacts\$packageName.zip"
          Write-Host "✓ Package created: artifacts\$packageName.zip" -ForegroundColor Green
'@
        }
    }
}

function Get-DeploymentEnvVars {
    param([string]$DeploymentType)
    
    switch ($DeploymentType) {
        'Azure' {
            return @"
  # Azure-specific settings
  AZURE_SUBSCRIPTION_ID: `${{ secrets.AZURE_SUBSCRIPTION_ID }}
  AZURE_TENANT_ID: `${{ secrets.AZURE_TENANT_ID }}
  AZURE_CLIENT_ID: `${{ secrets.AZURE_CLIENT_ID }}
  AZURE_CLIENT_SECRET: `${{ secrets.AZURE_CLIENT_SECRET }}
  AZURE_RESOURCE_GROUP: `${{ secrets.AZURE_RESOURCE_GROUP }}
  AZURE_APP_NAME: `${{ secrets.AZURE_APP_NAME }}
"@
        }
        'AKS' {
            return @"
  # AKS (Azure Kubernetes Service) settings
  AZURE_SUBSCRIPTION_ID: `${{ secrets.AZURE_SUBSCRIPTION_ID }}
  AKS_CLUSTER_NAME: `${{ secrets.AKS_CLUSTER_NAME }}
  AKS_RESOURCE_GROUP: `${{ secrets.AKS_RESOURCE_GROUP }}
  ACR_NAME: `${{ secrets.ACR_NAME }}
  ACR_USERNAME: `${{ secrets.ACR_USERNAME }}
  ACR_PASSWORD: `${{ secrets.ACR_PASSWORD }}
  KUBERNETES_NAMESPACE: `${{ secrets.KUBERNETES_NAMESPACE }}
"@
        }
        'IIS' {
            return @"
  # IIS (Internet Information Services) settings
  IIS_SERVER: `${{ secrets.IIS_SERVER }}
  IIS_SITE_NAME: `${{ secrets.IIS_SITE_NAME }}
  IIS_APP_POOL: `${{ secrets.IIS_APP_POOL }}
  IIS_DEPLOY_PATH: `${{ secrets.IIS_DEPLOY_PATH }}
  IIS_USERNAME: `${{ secrets.IIS_USERNAME }}
  IIS_PASSWORD: `${{ secrets.IIS_PASSWORD }}
"@
        }
    }
}

function Get-PreDeploymentSteps {
    param([string]$DeploymentType)
    
    switch ($DeploymentType) {
        'Azure' {
            return @"
      - name: Pre-deployment validation
        shell: pwsh
        run: |
          Write-Host "Validating Azure deployment prerequisites..." -ForegroundColor Cyan
          
          # Install Azure CLI if not present
          if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
            Write-Host "Installing Azure CLI..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
            Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
          }
          
          # Login to Azure
          Write-Host "Logging in to Azure..." -ForegroundColor Cyan
          az login --service-principal -u `$env:AZURE_CLIENT_ID -p `$env:AZURE_CLIENT_SECRET --tenant `$env:AZURE_TENANT_ID
          az account set --subscription `$env:AZURE_SUBSCRIPTION_ID
          
          # Verify target resource exists
          Write-Host "Verifying target resource..." -ForegroundColor Cyan
          az resource show --resource-group `$env:AZURE_RESOURCE_GROUP --name `$env:AZURE_APP_NAME --query "id" -o tsv
          
          Write-Host "✓ Pre-deployment validation complete" -ForegroundColor Green
"@
        }
        'AKS' {
            return @"
      - name: Pre-deployment validation
        shell: pwsh
        run: |
          Write-Host "Validating AKS deployment prerequisites..." -ForegroundColor Cyan
          
          # Install Azure CLI and kubectl
          if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
          }
          
          if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
            sudo az aks install-cli
          }
          
          # Login to Azure
          Write-Host "Logging in to Azure..." -ForegroundColor Cyan
          az login --service-principal -u `$env:AZURE_CLIENT_ID -p `$env:AZURE_CLIENT_SECRET --tenant `$env:AZURE_TENANT_ID
          az account set --subscription `$env:AZURE_SUBSCRIPTION_ID
          
          # Get AKS credentials
          Write-Host "Getting AKS credentials..." -ForegroundColor Cyan
          az aks get-credentials --resource-group `$env:AKS_RESOURCE_GROUP --name `$env:AKS_CLUSTER_NAME --overwrite-existing
          
          # Verify cluster connection
          kubectl cluster-info
          kubectl get nodes
          
          Write-Host "✓ Pre-deployment validation complete" -ForegroundColor Green
"@
        }
        'IIS' {
            return @"
      - name: Pre-deployment validation
        shell: pwsh
        run: |
          Write-Host "Validating IIS deployment prerequisites..." -ForegroundColor Cyan
          
          # Verify remote connection
          Write-Host "Testing connection to IIS server..." -ForegroundColor Cyan
          Test-NetConnection -ComputerName `$env:IIS_SERVER -Port 5985 -InformationLevel Detailed
          
          # Create PS Session
          `$securePassword = ConvertTo-SecureString `$env:IIS_PASSWORD -AsPlainText -Force
          `$credential = New-Object System.Management.Automation.PSCredential (`$env:IIS_USERNAME, `$securePassword)
          
          `$session = New-PSSession -ComputerName `$env:IIS_SERVER -Credential `$credential
          
          # Verify IIS is installed and running
          Invoke-Command -Session `$session -ScriptBlock {
            Import-Module WebAdministration
            Get-Website | Format-Table Name, State, PhysicalPath
          }
          
          Remove-PSSession `$session
          
          Write-Host "✓ Pre-deployment validation complete" -ForegroundColor Green
"@
        }
    }
}

function Get-DeploymentSteps {
    param([string]$ApplicationType, [string]$Language, [string]$DeploymentType)
    
    switch ($DeploymentType) {
        'Azure' {
            if ($ApplicationType -like '*Function*') {
                return @"
      - name: Deploy to Azure Functions
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to Azure Functions..." -ForegroundColor Cyan
          
          # Get the actual zipfile path
          `$zipFile = Get-ChildItem -Path "artifacts" -Filter "*.zip" | Select-Object -First 1 -ExpandProperty FullName
          
          # Extract package
          Expand-Archive -Path `$zipFile -DestinationPath "deploy" -Force
          
          # Deploy using Azure CLI
          az functionapp deployment source config-zip \`
            --resource-group `$env:AZURE_RESOURCE_GROUP \`
            --name `$env:AZURE_APP_NAME \`
            --src `$zipFile
          
          # Get function app URL
          `$appUrl = az functionapp show \`
            --resource-group `$env:AZURE_RESOURCE_GROUP \`
            --name `$env:AZURE_APP_NAME \`
            --query "defaultHostName" -o tsv
          
          Write-Host "app_url=https://`$appUrl" >> `$env:GITHUB_OUTPUT
          Write-Host "✓ Deployment complete: https://`$appUrl" -ForegroundColor Green
"@
            } elseif ($ApplicationType -like '*App Service*') {
                return @"
      - name: Deploy to Azure App Service
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to Azure App Service..." -ForegroundColor Cyan
          
          # Get the actual zipfile path
          `$zipFile = Get-ChildItem -Path "artifacts" -Filter "*.zip" | Select-Object -First 1 -ExpandProperty FullName
          
          # Deploy using Azure CLI
          az webapp deployment source config-zip \`
            --resource-group `$env:AZURE_RESOURCE_GROUP \`
            --name `$env:AZURE_APP_NAME \`
            --src `$zipFile
          
          # Get web app URL
          `$appUrl = az webapp show \`
            --resource-group `$env:AZURE_RESOURCE_GROUP \`
            --name `$env:AZURE_APP_NAME \`
            --query "defaultHostName" -o tsv
          
          Write-Host "app_url=https://`$appUrl" >> `$env:GITHUB_OUTPUT
          Write-Host "✓ Deployment complete: https://`$appUrl" -ForegroundColor Green
"@
            } else {
                return @"
      - name: Deploy to Azure
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to Azure..." -ForegroundColor Cyan
          
          # Generic Azure deployment
          # Customize based on your specific Azure service
          az deployment group create \`
            --resource-group `$env:AZURE_RESOURCE_GROUP \`
            --template-file deployment/azure-deploy.json \`
            --parameters @deployment/parameters.`$env:TARGET_ENV.json
          
          Write-Host "app_url=https://`$env:AZURE_APP_NAME.azurewebsites.net" >> `$env:GITHUB_OUTPUT
          Write-Host "✓ Deployment complete" -ForegroundColor Green
"@
            }
        }
        'AKS' {
            return @"
      - name: Deploy to AKS
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to Azure Kubernetes Service..." -ForegroundColor Cyan
          
          # Build and push Docker image
          Write-Host "Building Docker image..." -ForegroundColor Cyan
          docker build -t `$env:ACR_NAME.azurecr.io/`$env:APP_NAME:`$env:APP_VERSION .
          
          # Login to ACR
          Write-Host "Logging in to Azure Container Registry..." -ForegroundColor Cyan
          echo `$env:ACR_PASSWORD | docker login `$env:ACR_NAME.azurecr.io -u `$env:ACR_USERNAME --password-stdin
          
          # Push image
          Write-Host "Pushing image to ACR..." -ForegroundColor Cyan
          docker push `$env:ACR_NAME.azurecr.io/`$env:APP_NAME:`$env:APP_VERSION
          
          # Update Kubernetes deployment
          Write-Host "Updating Kubernetes deployment..." -ForegroundColor Cyan
          kubectl set image deployment/`$env:APP_NAME \`
            `$env:APP_NAME=`$env:ACR_NAME.azurecr.io/`$env:APP_NAME:`$env:APP_VERSION \`
            -n `$env:KUBERNETES_NAMESPACE
          
          # Wait for rollout
          kubectl rollout status deployment/`$env:APP_NAME -n `$env:KUBERNETES_NAMESPACE --timeout=300s
          
          # Get service URL
          `$serviceIP = kubectl get service `$env:APP_NAME -n `$env:KUBERNETES_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
          Write-Host "app_url=http://`$serviceIP" >> `$env:GITHUB_OUTPUT
          
          Write-Host "✓ Deployment complete: http://`$serviceIP" -ForegroundColor Green
"@
        }
        'IIS' {
            return @"
      - name: Deploy to IIS
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to IIS..." -ForegroundColor Cyan
          
          # Create credentials
          `$securePassword = ConvertTo-SecureString `$env:IIS_PASSWORD -AsPlainText -Force
          `$credential = New-Object System.Management.Automation.PSCredential (`$env:IIS_USERNAME, `$securePassword)
          
          # Create PS Session
          `$session = New-PSSession -ComputerName `$env:IIS_SERVER -Credential `$credential
          
          # Copy deployment package to remote server
          Write-Host "Copying deployment package..." -ForegroundColor Cyan
          Copy-Item -Path "artifacts/*.zip" -Destination "C:\Temp\" -ToSession `$session
          
          # Execute deployment on remote server
          Invoke-Command -Session `$session -ScriptBlock {
            param(`$appName, `$siteName, `$appPool, `$deployPath, `$version)
            
            Import-Module WebAdministration
            
            # Stop application pool
            Write-Host "Stopping application pool..." -ForegroundColor Yellow
            Stop-WebAppPool -Name `$appPool
            Start-Sleep -Seconds 5
            
            # Backup current deployment
            if (Test-Path `$deployPath) {
              `$backupPath = "`$deployPath-backup-`$(Get-Date -Format 'yyyyMMdd-HHmmss')"
              Write-Host "Creating backup at `$backupPath" -ForegroundColor Yellow
              Copy-Item -Path `$deployPath -Destination `$backupPath -Recurse -Force
            }
            
            # Extract new deployment
            Write-Host "Extracting deployment package..." -ForegroundColor Cyan
            Remove-Item -Path `$deployPath\* -Recurse -Force -ErrorAction SilentlyContinue
            Expand-Archive -Path "C:\Temp\`$appName-`$version.zip" -DestinationPath `$deployPath -Force
            
            # Start application pool
            Write-Host "Starting application pool..." -ForegroundColor Cyan
            Start-WebAppPool -Name `$appPool
            
            # Verify site is running
            `$site = Get-Website -Name `$siteName
            if (`$site.State -ne 'Started') {
              Start-Website -Name `$siteName
            }
            
            Write-Host "✓ Deployment complete" -ForegroundColor Green
          } -ArgumentList `$env:APP_NAME, `$env:IIS_SITE_NAME, `$env:IIS_APP_POOL, `$env:IIS_DEPLOY_PATH, `$env:APP_VERSION
          
          # Clean up
          Remove-PSSession `$session
          
          Write-Host "app_url=http://`$env:IIS_SERVER" >> `$env:GITHUB_OUTPUT
          Write-Host "✓ IIS deployment complete" -ForegroundColor Green
"@
        }
    }
}

function Get-PostDeploymentSteps {
    param([string]$DeploymentType, [string]$ApplicationType)
    
    return @"
      - name: Health check
        if: `${{ !inputs.skip_health_check }}
        shell: pwsh
        run: |
          Write-Host "Running post-deployment health checks..." -ForegroundColor Cyan
          
          `$appUrl = "`${{ steps.deploy.outputs.app_url }}"
          `$maxRetries = 10
          `$retryCount = 0
          `$healthCheckPassed = `$false
          
          while (`$retryCount -lt `$maxRetries) {
            try {
              `$retryCount++
              Write-Host "Health check attempt `$retryCount of `$maxRetries..." -ForegroundColor Yellow
              
              # Add your health check endpoint
              `$response = Invoke-WebRequest -Uri "`$appUrl/api/health" -Method Get -TimeoutSec 30 -UseBasicParsing
              
              if (`$response.StatusCode -eq 200) {
                Write-Host "✓ Health check passed!" -ForegroundColor Green
                `$healthCheckPassed = `$true
                break
              }
            }
            catch {
              Write-Host "Health check failed: `$_" -ForegroundColor Red
              if (`$retryCount -lt `$maxRetries) {
                Write-Host "Retrying in 30 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 30
              }
            }
          }
          
          if (-not `$healthCheckPassed) {
            Write-Host "⚠️  Health check failed after `$maxRetries attempts" -ForegroundColor Red
            exit 1
          }
      
      - name: Run smoke tests
        if: success()
        shell: pwsh
        run: |
          Write-Host "Running smoke tests..." -ForegroundColor Cyan
          
          # Add basic smoke tests here
          `$appUrl = "`${{ steps.deploy.outputs.app_url }}"
          
          # Test 1: Homepage
          try {
            `$response = Invoke-WebRequest -Uri "`$appUrl" -Method Get -TimeoutSec 30 -UseBasicParsing
            Write-Host "✓ Homepage accessible (Status: `$(`$response.StatusCode))" -ForegroundColor Green
          }
          catch {
            Write-Host "✗ Homepage test failed: `$_" -ForegroundColor Red
          }
          
          # Add more smoke tests as needed
          Write-Host "✓ Smoke tests complete" -ForegroundColor Green
"@
}

function Get-ConfigurationGuide {
    param([string]$ApplicationType, [string]$Language, [string]$DeploymentType, [string]$ProjectName)
    
    return @"
# Configuration Guide

This guide explains how to configure and use the generated CI/CD templates for your project.

## Project Information

- **Application Type**: $ApplicationType
- **Language**: $Language
- **Deployment Type**: $DeploymentType
- **Project Name**: $ProjectName

## Generated Files

1. **CI Template**: Builds, tests, scans, and publishes artifacts to JFrog
2. **CD Template**: Deploys application to $DeploymentType

## Prerequisites

### Required Tools

$( Get-RequiredTools -Language $Language -DeploymentType $DeploymentType )

### Required GitHub Secrets

Configure the following secrets in your GitHub repository (Settings > Secrets and variables > Actions):

#### JFrog Artifactory Secrets

- ``JFROG_URL``: Your JFrog Artifactory URL (e.g., https://yourcompany.jfrog.io)
- ``JFROG_REPOSITORY``: Target repository name in JFrog
- ``JFROG_USERNAME``: JFrog username or email
- ``JFROG_PASSWORD``: JFrog password or API token (recommended: use API token)

#### Security Scanning Secrets

- ``SONAR_TOKEN``: SonarQube authentication token (optional, for code quality analysis)
- ``SNYK_TOKEN``: Snyk authentication token (optional, for vulnerability scanning)

$( Get-DeploymentSecrets -DeploymentType $DeploymentType )

## Setup Instructions

### Step 1: Copy Templates to Your Repository

1. Copy the generated CI template to: ``.github/workflows/ci.yml``
2. Copy the generated CD template to: ``.github/workflows/cd.yml``

### Step 2: Configure GitHub Secrets

Add all required secrets listed above to your GitHub repository.

### Step 3: Customize Templates

Review and customize the following sections in the templates:

#### CI Template Customization

- **Build Configuration**: Adjust the ``BUILD_CONFIGURATION`` environment variable
- **Version Strategy**: Modify the ``APP_VERSION`` calculation if needed
- **Test Commands**: Update test execution commands for your project structure
- **Package Structure**: Adjust packaging logic based on your application structure

#### CD Template Customization

- **Environment Protection**: Configure environment protection rules in GitHub
- **Deployment Paths**: Update deployment paths and configuration based on your infrastructure
- **Health Check**: Customize the health check endpoint and validation logic
- **Rollback Strategy**: Implement appropriate rollback procedures for your deployment type

### Step 4: Test the Pipelines

1. **Test CI Pipeline**:
   - Push code to a feature branch
   - Verify the CI pipeline runs successfully
   - Check that artifacts are published to JFrog

2. **Test CD Pipeline**:
   - Trigger the CD workflow manually from GitHub Actions
   - Select the target environment and version
   - Verify deployment completes successfully

## Workflow Usage

### CI Pipeline

The CI pipeline automatically runs on:
- Push to ``main``, ``develop``, or ``feature/**`` branches
- Pull requests to ``main`` or ``develop``

You can also trigger it manually with options to skip tests.

### CD Pipeline

The CD pipeline is triggered manually using workflow_dispatch:

1. Go to Actions tab in GitHub
2. Select "CD - Deploy to $DeploymentType"
3. Click "Run workflow"
4. Select:
   - **Environment**: development, staging, or production
   - **Version**: Build number or version tag from JFrog
   - **Skip Health Check**: Optional, to skip post-deployment validation

## Best Practices

### Security

1. **Never hardcode secrets** in the YAML files
2. **Use GitHub Environments** with protection rules for production
3. **Rotate secrets regularly** and use API tokens instead of passwords
4. **Enable branch protection** rules for main branches

### Version Management

1. **Use semantic versioning** for releases
2. **Tag releases** in Git for easy rollback
3. **Keep artifacts** in JFrog for at least 30 days

### Deployment Strategy

1. **Test in development** first, then staging, then production
2. **Use blue-green deployment** or canary releases for zero-downtime deployments
3. **Have a rollback plan** ready before deploying to production
4. **Monitor applications** after deployment

## Troubleshooting

### Common Issues

#### CI Pipeline Fails at Build Step

- Verify the build configuration and SDK versions
- Check that all dependencies are accessible
- Review build logs for specific error messages

#### Artifacts Not Published to JFrog

- Verify JFrog credentials are correct
- Check that the repository exists and is accessible
- Ensure the JFrog CLI is properly configured

#### CD Pipeline Fails at Deployment

- Verify all deployment secrets are configured
- Check network connectivity to deployment target
- Review deployment logs for specific error messages

$( Get-DeploymentTroubleshooting -DeploymentType $DeploymentType )

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [JFrog Artifactory Documentation](https://www.jfrog.com/confluence/display/JFROG/JFrog+Artifactory)
$( Get-AdditionalResources -DeploymentType $DeploymentType )

## Support

For issues or questions about these templates:

1. Review the comments in the YAML files
2. Check the troubleshooting section above
3. Consult the official documentation for each tool
4. Contact your DevOps team for infrastructure-specific guidance

---

**Note**: These templates are generated based on your selections and may require adjustments
for your specific environment and requirements. Always test thoroughly in non-production
environments before deploying to production.
"@
}

function Get-RequiredTools {
    param([string]$Language, [string]$DeploymentType)
    
    $tools = @"
- **Git**: Version control
- **GitHub CLI** (optional): For easier workflow management
"@
    
    switch ($Language) {
        '.NET' { $tools += "`n- **.NET SDK**: Version 6.0 or later" }
        'Python' { $tools += "`n- **Python**: Version 3.8 or later`n- **pip**: Python package manager" }
        'Node' { $tools += "`n- **Node.js**: Version 16 or later`n- **npm**: Node package manager" }
    }
    
    switch ($DeploymentType) {
        'Azure' { $tools += "`n- **Azure CLI**: For Azure deployments" }
        'AKS' { $tools += "`n- **Azure CLI**: For Azure authentication`n- **kubectl**: Kubernetes command-line tool`n- **Docker**: For building container images" }
        'IIS' { $tools += "`n- **PowerShell 5.1+**: For remote IIS management`n- **IIS Management Tools**: On deployment target" }
    }
    
    return $tools
}

function Get-DeploymentSecrets {
    param([string]$DeploymentType)
    
    switch ($DeploymentType) {
        'Azure' {
            return @"

#### Azure Deployment Secrets

- ``AZURE_SUBSCRIPTION_ID``: Azure subscription ID
- ``AZURE_TENANT_ID``: Azure Active Directory tenant ID
- ``AZURE_CLIENT_ID``: Service principal client ID
- ``AZURE_CLIENT_SECRET``: Service principal client secret
- ``AZURE_RESOURCE_GROUP``: Target resource group name
- ``AZURE_APP_NAME``: Azure app service or function app name
"@
        }
        'AKS' {
            return @"

#### AKS Deployment Secrets

- ``AZURE_SUBSCRIPTION_ID``: Azure subscription ID
- ``AZURE_TENANT_ID``: Azure Active Directory tenant ID (if using service principal)
- ``AZURE_CLIENT_ID``: Service principal client ID (if using service principal)
- ``AZURE_CLIENT_SECRET``: Service principal client secret (if using service principal)
- ``AKS_CLUSTER_NAME``: Name of the AKS cluster
- ``AKS_RESOURCE_GROUP``: Resource group containing the AKS cluster
- ``ACR_NAME``: Azure Container Registry name
- ``ACR_USERNAME``: ACR username
- ``ACR_PASSWORD``: ACR password or token
- ``KUBERNETES_NAMESPACE``: Kubernetes namespace for deployment
"@
        }
        'IIS' {
            return @"

#### IIS Deployment Secrets

- ``IIS_SERVER``: IIS server hostname or IP address
- ``IIS_SITE_NAME``: IIS website name
- ``IIS_APP_POOL``: IIS application pool name
- ``IIS_DEPLOY_PATH``: Physical path for deployment (e.g., C:\inetpub\wwwroot\myapp)
- ``IIS_USERNAME``: Windows username with deployment permissions
- ``IIS_PASSWORD``: Windows password for deployment user
"@
        }
    }
}

function Get-DeploymentTroubleshooting {
    param([string]$DeploymentType)
    
    switch ($DeploymentType) {
        'Azure' {
            return @"

#### Azure-Specific Issues

- **Authentication Failed**: Verify service principal credentials and permissions
- **Resource Not Found**: Check resource group and app name are correct
- **Deployment Timeout**: Increase timeout settings or check Azure service health
"@
        }
        'AKS' {
            return @"

#### AKS-Specific Issues

- **Cannot Connect to Cluster**: Verify AKS credentials and firewall rules
- **Image Pull Failed**: Check ACR credentials and image name
- **Pod Not Starting**: Review pod logs with ``kubectl logs`` and ``kubectl describe pod``
- **Service Not Accessible**: Verify service type and ingress configuration
"@
        }
        'IIS' {
            return @"

#### IIS-Specific Issues

- **Cannot Connect to Server**: Check WinRM configuration and firewall rules
- **Permission Denied**: Verify deployment user has appropriate IIS permissions
- **Application Pool Fails to Start**: Check .NET version and dependencies
- **File Lock Errors**: Ensure application pool is stopped before deployment
"@
        }
    }
}

function Get-AdditionalResources {
    param([string]$DeploymentType)
    
    $resources = ""
    
    switch ($DeploymentType) {
        'Azure' {
            $resources = @"
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
"@
        }
        'AKS' {
            $resources = @"
- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
"@
        }
        'IIS' {
            $resources = @"
- [IIS Documentation](https://docs.microsoft.com/en-us/iis/)
- [PowerShell Remoting Documentation](https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands)
"@
        }
    }
    
    return $resources
}

# ============================================================================
# REUSABLE WORKFLOW TEMPLATES
# ============================================================================

function Get-ReusableCIWorkflow {
    param(
        [string]$Language
    )
    param([string]$DeploymentType)
    
    switch ($DeploymentType) {
        'Azure' {
            return @"
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
"@
        }
        'AKS' {
            return @"
- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Docker Documentation](https://docs.docker.com/)
"@
        }
        'IIS' {
            return @"
- [IIS Documentation](https://docs.microsoft.com/en-us/iis/)
- [PowerShell Remoting Documentation](https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands)
"@
        }
    }
}
