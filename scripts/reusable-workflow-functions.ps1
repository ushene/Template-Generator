#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Reusable Workflow Template Functions

.DESCRIPTION
    This module contains functions to generate reusable GitHub Actions workflows
    for CI/CD pipelines that can be called from other workflows.
#>

function Get-LanguageVersionInputName {
    param([string]$Language)

    switch ($Language) {
        '.NET' { return 'dotnet-version' }
        'Python' { return 'python-version' }
        'Node' { return 'node-version' }
        default { return ($Language -replace '\.', '').ToLower() + '-version' }
    }
}

function Get-LanguageSlug {
    param([string]$Language)

    switch ($Language) {
        '.NET' { return 'net' }
        'Python' { return 'python' }
        'Node' { return 'node' }
        default { return ($Language -replace '\.', '').ToLower() }
    }
}

function Get-ReusableCIWorkflow {
    param(
        [string]$Language
    )
    
    $versionInputName = Get-LanguageVersionInputName -Language $Language
    $langSlug = Get-LanguageSlug -Language $Language

    $buildSteps = ""
    $restoreCommand = ""
    $buildCommand = ""
    $testCommand = ""
    $packageCommand = ""
    
    switch ($Language) {
        '.NET' {
            $buildSteps = 'dotnet-version: ${{ inputs.dotnet-version }}'
            $restoreCommand = 'dotnet restore'
            $buildCommand = 'dotnet build --configuration $env:BUILD_CONFIGURATION --no-restore'
            $testCommand = 'dotnet test --no-build --configuration $env:BUILD_CONFIGURATION --logger "trx;LogFileName=test-results.trx" --collect:"XPlat Code Coverage"'
            $packageCommand = @'
          $publishDir = "publish"
          dotnet publish --configuration $env:BUILD_CONFIGURATION --output $publishDir --no-build
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          Compress-Archive -Path "$publishDir\*" -DestinationPath "artifacts\$packageName.zip"
'@
        }
        'Python' {
            $buildSteps = 'python-version: ${{ inputs.python-version }}'
            $restoreCommand = 'if (Test-Path "requirements.txt") { pip install -r requirements.txt }'
            $buildCommand = 'Write-Host "Python project - skipping build step" -ForegroundColor Yellow'
            $testCommand = 'pytest --cov=. --cov-report=xml --cov-report=html'
            $packageCommand = @'
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          if (Test-Path "requirements.txt") { pip install -r requirements.txt -t artifacts/ }
          Copy-Item -Path "*.py" -Destination "artifacts/" -Recurse -Force
          Compress-Archive -Path "artifacts\*" -DestinationPath "artifacts\$packageName.zip"
'@
        }
        'Node' {
            $buildSteps = 'node-version: ${{ inputs.node-version }}'
            $restoreCommand = 'npm ci'
            $buildCommand = 'npm run build'
            $testCommand = 'npm test -- --coverage --ci'
            $packageCommand = @'
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          Copy-Item -Path "package.json","package-lock.json","dist/","build/","node_modules/" -Destination "artifacts/" -Recurse -Force -ErrorAction SilentlyContinue
          Compress-Archive -Path "artifacts\*" -DestinationPath "artifacts\$packageName.zip"
'@
        }
    }
    
    $langLower = $Language -replace '\.', ''
    
    $template = @"
# Reusable CI Workflow
# Language: $Language
# Purpose: Build, test, scan, and publish artifacts to JFrog
# This workflow can be called from other workflows using workflow_call

name: Reusable CI - $Language

on:
  workflow_call:
    inputs:
      app-name:
        description: 'Application name'
        required: true
        type: string
      build-configuration:
        description: 'Build configuration (Release/Debug)'
        required: false
        type: string
        default: 'Release'
      `$( $versionInputName ):\n        description: '$Language SDK/Runtime version'
        required: false
        type: string
        default: `$( if ($Language -eq '.NET') { "'8.x'" } elseif ($Language -eq 'Python') { "'3.11'" } else { "'20'" } )
      skip-tests:
        description: 'Skip running tests'
        required: false
        type: boolean
        default: false
      skip-security-scan:
        description: 'Skip security scanning'
        required: false
        type: boolean
        default: false
      runner:
        description: 'GitHub runner to use'
        required: false
        type: string
        default: 'ubuntu-latest'
      jfrog-repository:
        description: 'JFrog repository name'
        required: false
        type: string
        default: ''
    
    outputs:
      artifact-version:
        description: 'Version of the built artifact'
        value: `${{ jobs.build.outputs.version }}
      artifact-name:
        description: 'Name of the artifact'
        value: `${{ jobs.build.outputs.artifact }}
      build-status:
        description: 'Build status (success/failure)'
        value: `${{ jobs.build.outputs.status }}
    
    secrets:
      JFROG_URL:
        description: 'JFrog Artifactory URL'
        required: true
      JFROG_USERNAME:
        description: 'JFrog username'
        required: true
      JFROG_PASSWORD:
        description: 'JFrog password or API token'
        required: true
      SONAR_TOKEN:
        description: 'SonarQube token'
        required: false
      SNYK_TOKEN:
        description: 'Snyk token'
        required: false

env:
  BUILD_CONFIGURATION: `${{ inputs.build-configuration }}
  APP_NAME: `${{ inputs.app-name }}
  APP_VERSION: `${{ github.run_number }}

jobs:
  build:
    name: Build and Test
    runs-on: `${{ inputs.runner }}
    
    outputs:
      version: `${{ steps.set-version.outputs.version }}
      artifact: `${{ steps.set-version.outputs.artifact }}
      status: `${{ steps.set-status.outputs.status }}
    
    steps:
      # Step 1: Checkout source code
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      # Step 2: Set version output
      - name: Set version
        id: set-version
        shell: pwsh
        run: |
          `$version = "`${{ github.run_number }}"
          `$artifact = "`${{ inputs.app-name }}-`$version"
          Write-Host "version=`$version" >> `$env:GITHUB_OUTPUT
          Write-Host "artifact=`$artifact" >> `$env:GITHUB_OUTPUT
          Write-Host "Building version: `$version" -ForegroundColor Cyan
      
      # Step 3: Setup build environment
      - name: Setup $Language
        uses: $( if ($Language -eq '.NET') { 'actions/setup-dotnet@v4' } elseif ($Language -eq 'Python') { 'actions/setup-python@v5' } else { 'actions/setup-node@v4' } )
        with:
          $buildSteps
      
      - name: Display $Language version
        shell: pwsh
        run: |
          Write-Host "$Language Version:" -ForegroundColor Cyan
          $( if ($Language -eq '.NET') { 'dotnet --version' } elseif ($Language -eq 'Python') { 'python --version' } else { 'node --version' } )
      
      # Step 4: Restore dependencies
      - name: Restore dependencies
        shell: pwsh
        run: |
          Write-Host "Restoring project dependencies..." -ForegroundColor Cyan
          $restoreCommand
      
      # Step 5: Build application
      - name: Build application
        shell: pwsh
        run: |
          Write-Host "Building application in `$env:BUILD_CONFIGURATION mode..." -ForegroundColor Cyan
          $buildCommand
      
      # Step 6: Run unit tests
      - name: Run unit tests
        if: `${{ !inputs.skip-tests }}
        shell: pwsh
        run: |
          Write-Host "Running unit tests..." -ForegroundColor Cyan
          $testCommand
      
      - name: Publish test results
        if: always() && !inputs.skip-tests
        uses: actions/upload-artifact@v4
        with:
          name: test-results-`${{ github.run_number }}
          path: |
            **/test-results.trx
            coverage.xml
            htmlcov/
            coverage/
      
      # Step 7: Security scanning
      - name: Run SonarQube analysis
        if: `${{ !inputs.skip-security-scan && secrets.SONAR_TOKEN != '' }}
        shell: pwsh
        run: |
          Write-Host "Running SonarQube code quality analysis..." -ForegroundColor Cyan
          Write-Host "SonarQube analysis configured - implement based on your setup" -ForegroundColor Yellow
      
      - name: Run Snyk security scan
        if: `${{ !inputs.skip-security-scan && secrets.SNYK_TOKEN != '' }}
        shell: pwsh
        run: |
          Write-Host "Running Snyk security vulnerability scan..." -ForegroundColor Cyan
          npm install -g snyk
          snyk auth `${{ secrets.SNYK_TOKEN }}
          snyk test --severity-threshold=high || true
          snyk monitor
      
      # Step 8: Package application
      - name: Package application
        shell: pwsh
        run: |
          Write-Host "Packaging application..." -ForegroundColor Cyan
          `$packageName = "`$env:APP_NAME-`$env:APP_VERSION"
          $packageCommand
          Write-Host "âœ“ Package created: artifacts/`$packageName.zip" -ForegroundColor Green
      
      # Step 9: Publish to JFrog Artifactory
      - name: Publish to JFrog
        if: inputs.jfrog-repository != ''
        shell: pwsh
        run: |
          Write-Host "Publishing artifacts to JFrog Artifactory..." -ForegroundColor Cyan
          
          # Setup JFrog CLI
          if (-not (Get-Command jfrog -ErrorAction SilentlyContinue)) {
            Write-Host "Installing JFrog CLI..." -ForegroundColor Yellow
            curl -fL https://install-cli.jfrog.io | sh
            sudo mv jfrog /usr/local/bin/
          }
          
          # Configure JFrog CLI
          jfrog config add artifactory --url="`${{ secrets.JFROG_URL }}" --user="`${{ secrets.JFROG_USERNAME }}" --password="`${{ secrets.JFROG_PASSWORD }}" --interactive=false
          
          # Upload artifacts
          `$targetPath = "`${{ inputs.jfrog-repository }}/`$env:APP_NAME/`$env:APP_VERSION/"
          Write-Host "Uploading to `$targetPath" -ForegroundColor Cyan
          jfrog rt upload "artifacts/*" "`$targetPath" --flat=false --recursive=true
          
          Write-Host "âœ“ Artifacts published successfully" -ForegroundColor Green
      
      # Step 10: Upload build artifacts to GitHub
      - name: Upload artifacts to GitHub
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts-`${{ inputs.app-name }}-`${{ github.run_number }}
          path: artifacts/
          retention-days: 30
      
      # Step 11: Set build status
      - name: Set build status
        id: set-status
        if: always()
        shell: pwsh
        run: |
          `$status = "`${{ job.status }}"
          Write-Host "status=`$status" >> `$env:GITHUB_OUTPUT
          Write-Host "`n=== Build Summary ===" -ForegroundColor Green
          Write-Host "Application: `$env:APP_NAME" -ForegroundColor Cyan
          Write-Host "Version: `$env:APP_VERSION" -ForegroundColor Cyan
          Write-Host "Configuration: `$env:BUILD_CONFIGURATION" -ForegroundColor Cyan
          Write-Host "Status: `$status" -ForegroundColor Cyan
          Write-Host "========================`n" -ForegroundColor Green
"@
    
    return $template
}

function Get-ReusableCDWorkflow {
    param(
        [string]$DeploymentType
    )
    
    $preDeploySteps = ""
    $deploySteps = ""
    $postDeploySteps = ""
    $runnerOS = if ($DeploymentType -eq 'IIS') { 'windows-latest' } else { 'ubuntu-latest' }
    
    # Generate deployment-specific steps
    switch ($DeploymentType) {
        'Azure' {
            $preDeploySteps = @'
      - name: Azure Login
        shell: pwsh
        run: |
          Write-Host "Logging in to Azure..." -ForegroundColor Cyan
          az login --service-principal -u ${{ secrets.AZURE_CLIENT_ID }} -p ${{ secrets.AZURE_CLIENT_SECRET }} --tenant ${{ secrets.AZURE_TENANT_ID }}
          az account set --subscription ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          Write-Host "âœ“ Azure login successful" -ForegroundColor Green
'@
            
            $deploySteps = @'
      - name: Deploy to Azure
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to Azure..." -ForegroundColor Cyan
          
          # Deploy based on resource type
          $resourceType = "${{ inputs.resource-type }}"
          
          if ($resourceType -eq "webapp") {
            $zipFile = Get-ChildItem -Path "artifacts" -Filter "*.zip" | Select-Object -First 1 -ExpandProperty FullName
            if (-not $zipFile) { throw "No deployment package found in artifacts folder" }
            az webapp deployment source config-zip `
              --resource-group ${{ inputs.resource-group }} `
              --name ${{ inputs.resource-name }} `
              --src "$zipFile"
              
            $appUrl = az webapp show `
              --resource-group ${{ inputs.resource-group }} `
              --name ${{ inputs.resource-name }} `
              --query "defaultHostName" -o tsv
              
            Write-Host "app_url=https://$appUrl" >> $env:GITHUB_OUTPUT
          }
          elseif ($resourceType -eq "functionapp") {
            $zipFile = Get-ChildItem -Path "artifacts" -Filter "*.zip" | Select-Object -First 1 -ExpandProperty FullName
            if (-not $zipFile) { throw "No deployment package found in artifacts folder" }
            az functionapp deployment source config-zip `
              --resource-group ${{ inputs.resource-group }} `
              --name ${{ inputs.resource-name }} `
              --src "$zipFile"
              
            $appUrl = az functionapp show `
              --resource-group ${{ inputs.resource-group }} `
              --name ${{ inputs.resource-name }} `
              --query "defaultHostName" -o tsv
              
            Write-Host "app_url=https://$appUrl" >> $env:GITHUB_OUTPUT
          }
          
          Write-Host "âœ“ Deployment complete" -ForegroundColor Green
'@
        }
        'AKS' {
            $preDeploySteps = @'
      - name: Setup Kubernetes
        shell: pwsh
        run: |
          Write-Host "Setting up Kubernetes..." -ForegroundColor Cyan
          az login --service-principal -u ${{ secrets.AZURE_CLIENT_ID }} -p ${{ secrets.AZURE_CLIENT_SECRET }} --tenant ${{ secrets.AZURE_TENANT_ID }}
          az aks get-credentials --resource-group ${{ inputs.aks-resource-group }} --name ${{ inputs.aks-cluster-name }}
          kubectl cluster-info
          Write-Host "âœ“ Kubernetes setup complete" -ForegroundColor Green
'@
            
            $deploySteps = @'
      - name: Deploy to AKS
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to Azure Kubernetes Service..." -ForegroundColor Cyan
          
          # Build and push Docker image
          docker build -t ${{ inputs.acr-name }}.azurecr.io/${{ inputs.app-name }}:${{ inputs.version }} .
          
          # Login to ACR
          echo ${{ secrets.ACR_PASSWORD }} | docker login ${{ inputs.acr-name }}.azurecr.io -u ${{ inputs.acr-username }} --password-stdin
          
          # Push image
          docker push ${{ inputs.acr-name }}.azurecr.io/${{ inputs.app-name }}:${{ inputs.version }}
          
          # Update deployment
          kubectl set image deployment/${{ inputs.app-name }} `
            ${{ inputs.app-name }}=${{ inputs.acr-name }}.azurecr.io/${{ inputs.app-name }}:${{ inputs.version }} `
            -n ${{ inputs.kubernetes-namespace }}
          
          kubectl rollout status deployment/${{ inputs.app-name }} -n ${{ inputs.kubernetes-namespace }} --timeout=300s
          
          $serviceIP = kubectl get service ${{ inputs.app-name }} -n ${{ inputs.kubernetes-namespace }} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
          Write-Host "app_url=http://$serviceIP" >> $env:GITHUB_OUTPUT
          
          Write-Host "âœ“ Deployment complete" -ForegroundColor Green
'@
        }
        'IIS' {
            $preDeploySteps = @'
      - name: Validate IIS Connection
        shell: pwsh
        run: |
          Write-Host "Validating IIS server connection..." -ForegroundColor Cyan
          Test-NetConnection -ComputerName ${{ inputs.iis-server }} -Port 5985 -InformationLevel Detailed
          Write-Host "âœ“ Connection validated" -ForegroundColor Green
'@
            
            $deploySteps = @'
      - name: Deploy to IIS
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to IIS..." -ForegroundColor Cyan
          
          $securePassword = ConvertTo-SecureString ${{ secrets.IIS_PASSWORD }} -AsPlainText -Force
          $credential = New-Object System.Management.Automation.PSCredential (${{ secrets.IIS_USERNAME }}, $securePassword)
          
          $session = New-PSSession -ComputerName ${{ inputs.iis-server }} -Credential $credential
          
          Copy-Item -Path "artifacts/*.zip" -Destination "C:\Temp\" -ToSession $session
          
          Invoke-Command -Session $session -ScriptBlock {
            param($appName, $siteName, $appPool, $deployPath, $version)
            
            Import-Module WebAdministration
            Stop-WebAppPool -Name $appPool
            Start-Sleep -Seconds 5
            
            if (Test-Path $deployPath) {
              $backupPath = "$deployPath-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
              Copy-Item -Path $deployPath -Destination $backupPath -Recurse -Force
            }
            
            Remove-Item -Path $deployPath\* -Recurse -Force -ErrorAction SilentlyContinue
            Expand-Archive -Path "C:\Temp\$appName-$version.zip" -DestinationPath $deployPath -Force
            
            Start-WebAppPool -Name $appPool
            
            $site = Get-Website -Name $siteName
            if ($site.State -ne 'Started') {
              Start-Website -Name $siteName
            }
          } -ArgumentList "${{ inputs.app-name }}", "${{ inputs.iis-site-name }}", "${{ inputs.iis-app-pool }}", "${{ inputs.iis-deploy-path }}", "${{ inputs.version }}"
          
          Remove-PSSession $session
          
          Write-Host "app_url=http://${{ inputs.iis-server }}" >> $env:GITHUB_OUTPUT
          Write-Host "âœ“ Deployment complete" -ForegroundColor Green
'@
        }
    }
    
    $template = @"
# Reusable CD Workflow
# Deployment Type: $DeploymentType
# Purpose: Deploy application to $DeploymentType
# This workflow can be called from other workflows using workflow_call

name: Reusable CD - $DeploymentType

on:
  workflow_call:
    inputs:
      app-name:
        description: 'Application name'
        required: true
        type: string
      version:
        description: 'Version to deploy'
        required: true
        type: string
      environment:
        description: 'Target environment'
        required: true
        type: string
      skip-health-check:
        description: 'Skip post-deployment health check'
        required: false
        type: boolean
        default: false
      runner:
        description: 'GitHub runner to use'
        required: false
        type: string
        default: '$runnerOS'
      jfrog-repository:
        description: 'JFrog repository name'
        required: true
        type: string
      $( if ($DeploymentType -eq 'Azure') {
@"
resource-group:
        description: 'Azure resource group'
        required: true
        type: string
      resource-name:
        description: 'Azure resource name'
        required: true
        type: string
      resource-type:
        description: 'Azure resource type (webapp/functionapp)'
        required: false
        type: string
        default: 'webapp'
"@
      } elseif ($DeploymentType -eq 'AKS') {
@"
aks-cluster-name:
        description: 'AKS cluster name'
        required: true
        type: string
      aks-resource-group:
        description: 'AKS resource group'
        required: true
        type: string
      acr-name:
        description: 'Azure Container Registry name'
        required: true
        type: string
      acr-username:
        description: 'ACR username'
        required: true
        type: string
      kubernetes-namespace:
        description: 'Kubernetes namespace'
        required: false
        type: string
        default: 'default'
"@
      } elseif ($DeploymentType -eq 'IIS') {
@"
iis-server:
        description: 'IIS server hostname or IP'
        required: true
        type: string
      iis-site-name:
        description: 'IIS website name'
        required: true
        type: string
      iis-app-pool:
        description: 'IIS application pool name'
        required: true
        type: string
      iis-deploy-path:
        description: 'IIS deployment path'
        required: true
        type: string
"@
      } )
    
    outputs:
      deployment-url:
        description: 'URL of the deployed application'
        value: `${{ jobs.deploy.outputs.url }}
      deployment-status:
        description: 'Deployment status (success/failure)'
        value: `${{ jobs.deploy.outputs.status }}
    
    secrets:
      JFROG_URL:
        description: 'JFrog Artifactory URL'
        required: true
      JFROG_USERNAME:
        description: 'JFrog username'
        required: true
      JFROG_PASSWORD:
        description: 'JFrog password or API token'
        required: true
      $( if ($DeploymentType -in @('Azure', 'AKS')) {
@"
AZURE_SUBSCRIPTION_ID:
        description: 'Azure subscription ID'
        required: true
      AZURE_TENANT_ID:
        description: 'Azure tenant ID'
        required: true
      AZURE_CLIENT_ID:
        description: 'Azure client ID'
        required: true
      AZURE_CLIENT_SECRET:
        description: 'Azure client secret'
        required: true
"@
      } )
      $( if ($DeploymentType -eq 'AKS') {
@"
ACR_PASSWORD:
        description: 'Azure Container Registry password'
        required: true
"@
      } )
      $( if ($DeploymentType -eq 'IIS') {
@"
IIS_USERNAME:
        description: 'IIS deployment username'
        required: true
      IIS_PASSWORD:
        description: 'IIS deployment password'
        required: true
"@
      } )

env:
  APP_NAME: `${{ inputs.app-name }}
  APP_VERSION: `${{ inputs.version }}
  TARGET_ENV: `${{ inputs.environment }}

jobs:
  deploy:
    name: Deploy to `${{ inputs.environment }}
    runs-on: `${{ inputs.runner }}
    
    environment:
      name: `${{ inputs.environment }}
      url: `${{ steps.deploy.outputs.app_url }}
    
    outputs:
      url: `${{ steps.deploy.outputs.app_url }}
      status: `${{ steps.set-status.outputs.status }}
    
    steps:
      # Step 1: Checkout repository
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          sparse-checkout: |
            deployment/
            scripts/
      
      # Step 2: Download artifacts from JFrog
      - name: Download artifacts from JFrog
        shell: pwsh
        run: |
          Write-Host "Downloading artifacts from JFrog..." -ForegroundColor Cyan
          
          if (-not (Get-Command jfrog -ErrorAction SilentlyContinue)) {
            Write-Host "Installing JFrog CLI..." -ForegroundColor Yellow
            $( if ($DeploymentType -eq 'IIS') {
                'Invoke-WebRequest -Uri "https://releases.jfrog.io/artifactory/jfrog-cli/v2/[RELEASE]/jfrog-cli-windows-amd64/jfrog.exe" -OutFile "jfrog.exe"'
            } else {
                'curl -fL https://install-cli.jfrog.io | sh; sudo mv jfrog /usr/local/bin/'
            } )
          }
          
          jfrog config add artifactory --url="`${{ secrets.JFROG_URL }}" --user="`${{ secrets.JFROG_USERNAME }}" --password="`${{ secrets.JFROG_PASSWORD }}" --interactive=false
          
          `$artifactPath = "`${{ inputs.jfrog-repository }}/`${{ inputs.app-name }}/`${{ inputs.version }}/"
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          jfrog rt download "`$artifactPath" "artifacts/" --flat=false --recursive=true
          
          Write-Host "âœ“ Artifacts downloaded" -ForegroundColor Green
      
      # Step 3: Pre-deployment steps
$preDeploySteps
      
      # Step 4: Deploy application
$deploySteps
      
      # Step 5: Health check
      - name: Health check
        if: `${{ !inputs.skip-health-check }}
        shell: pwsh
        run: |
          Write-Host "Running health checks..." -ForegroundColor Cyan
          
          `$appUrl = "`${{ steps.deploy.outputs.app_url }}"
          `$maxRetries = 10
          `$retryCount = 0
          
          while (`$retryCount -lt `$maxRetries) {
            try {
              `$retryCount++
              Write-Host "Healthcheck attempt `$retryCount of `$maxRetries..." -ForegroundColor Yellow
              
              `$response = Invoke-WebRequest -Uri "`$appUrl/health" -Method Get -TimeoutSec 30
              
              if (`$response.StatusCode -eq 200) {
                Write-Host "âœ“ Health check passed!" -ForegroundColor Green
                break
              }
            }
            catch {
              if (`$retryCount -lt `$maxRetries) {
                Start-Sleep -Seconds 30
              } else {
                Write-Host "âš ï¸  Health check failed" -ForegroundColor Red
                exit 1
              }
            }
          }
      
      # Step 6: Set deployment status
      - name: Set deployment status
        id: set-status
        if: always()
        shell: pwsh
        run: |
          `$status = "`${{ job.status }}"
          Write-Host "status=`$status" >> `$env:GITHUB_OUTPUT
          Write-Host "`n=== Deployment Summary ===" -ForegroundColor Green
          Write-Host "Application: `${{ inputs.app-name }}" -ForegroundColor Cyan
          Write-Host "Version: `${{ inputs.version }}" -ForegroundColor Cyan
          Write-Host "Environment: `${{ inputs.environment }}" -ForegroundColor Cyan
          Write-Host "Status: `$status" -ForegroundColor Cyan
          Write-Host "===========================`n" -ForegroundColor Green
"@
    
    return $template
}

function Get-MainBuildWorkflow {
    param(
        [string]$Language,
        [string]$DeploymentType,
        [string]$ProjectName
    )
    
    $langLower = Get-LanguageSlug -Language $Language
    $versionInputName = Get-LanguageVersionInputName -Language $Language
    $defaultVersion = if ($Language -eq '.NET') { '8.x' } elseif ($Language -eq 'Python') { '3.11' } else { '20' }
    
    $template = @"
# Main Build Workflow
# Project: $ProjectName
# Language: $Language
# Deployment: $DeploymentType
# Purpose: Orchestrates CI/CD using reusable workflows

name: Build and Deploy

on:
  push:
    branches:
      - main
      - develop
      - 'feature/**'
      - 'release/**'
  pull_request:
    branches:
      - main
      - develop
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deploy to environment'
        required: false
        type: choice
        options:
          - none
          - development
          - staging
          - production
        default: 'none'
      skip_tests:
        description: 'Skip running tests'
        required: false
        type: boolean
        default: false

# Global environment variables
env:
  APP_NAME: '$ProjectName'
  JFROG_REPOSITORY: $( if ($DeploymentType -eq 'Azure') { "'azure-apps'" } elseif ($DeploymentType -eq 'AKS') { "'kubernetes-apps'" } else { "'iis-apps'" } )

jobs:
  # Job 1: Build using reusable CI workflow
  build:
    name: Build Application
    uses: ./.github/workflows/reusable-ci-$langLower.yml
    with:
      app-name: `${{ env.APP_NAME }}
      build-configuration: 'Release'
      `$( $versionInputName ): '$defaultVersion'
      skip-tests: `${{ inputs.skip_tests || false }}
      skip-security-scan: false
      jfrog-repository: `${{ env.JFROG_REPOSITORY }}
    secrets:
      JFROG_URL: `${{ secrets.JFROG_URL }}
      JFROG_USERNAME: `${{ secrets.JFROG_USERNAME }}
      JFROG_PASSWORD: `${{ secrets.JFROG_PASSWORD }}
      SONAR_TOKEN: `${{ secrets.SONAR_TOKEN }}
      SNYK_TOKEN: `${{ secrets.SNYK_TOKEN }}
  
  # Job 2: Deploy to development (automatic on develop branch)
  deploy-dev:
    name: Deploy to Development
    if: github.ref == 'refs/heads/develop' && github.event_name == 'push'
    needs: build
    uses: ./.github/workflows/reusable-cd-$( $DeploymentType.ToLower() ).yml
    with:
      app-name: `${{ env.APP_NAME }}
      version: `${{ needs.build.outputs.artifact-version }}
      environment: 'development'
      skip-health-check: false
      jfrog-repository: `${{ env.JFROG_REPOSITORY }}
      $( if ($DeploymentType -eq 'Azure') {
@"
resource-group: `${{ vars.DEV_RESOURCE_GROUP }}
      resource-name: `${{ vars.DEV_RESOURCE_NAME }}
      resource-type: 'webapp'
"@
      } elseif ($DeploymentType -eq 'AKS') {
@"
aks-cluster-name: `${{ vars.DEV_AKS_CLUSTER }}
      aks-resource-group: `${{ vars.DEV_AKS_RG }}
      acr-name: `${{ vars.ACR_NAME }}
      acr-username: `${{ vars.ACR_USERNAME }}
      kubernetes-namespace: 'development'
"@
      } elseif ($DeploymentType -eq 'IIS') {
@"
iis-server: `${{ vars.DEV_IIS_SERVER }}
      iis-site-name: `${{ vars.DEV_IIS_SITE }}
      iis-app-pool: `${{ vars.DEV_IIS_POOL }}
      iis-deploy-path: `${{ vars.DEV_IIS_PATH }}
"@
      } )
    secrets: inherit
  
  # Job 3: Deploy to staging (automatic on main branch)
  deploy-staging:
    name: Deploy to Staging
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    needs: build
    uses: ./.github/workflows/reusable-cd-$( $DeploymentType.ToLower() ).yml
    with:
      app-name: `${{ env.APP_NAME }}
      version: `${{ needs.build.outputs.artifact-version }}
      environment: 'staging'
      skip-health-check: false
      jfrog-repository: `${{ env.JFROG_REPOSITORY }}
      $( if ($DeploymentType -eq 'Azure') {
@"
resource-group: `${{ vars.STAGING_RESOURCE_GROUP }}
      resource-name: `${{ vars.STAGING_RESOURCE_NAME }}
      resource-type: 'webapp'
"@
      } elseif ($DeploymentType -eq 'AKS') {
@"
aks-cluster-name: `${{ vars.STAGING_AKS_CLUSTER }}
      aks-resource-group: `${{ vars.STAGING_AKS_RG }}
      acr-name: `${{ vars.ACR_NAME }}
      acr-username: `${{ vars.ACR_USERNAME }}
      kubernetes-namespace: 'staging'
"@
      } elseif ($DeploymentType -eq 'IIS') {
@"
iis-server: `${{ vars.STAGING_IIS_SERVER }}
      iis-site-name: `${{ vars.STAGING_IIS_SITE }}
      iis-app-pool: `${{ vars.STAGING_IIS_POOL }}
      iis-deploy-path: `${{ vars.STAGING_IIS_PATH }}
"@
      } )
    secrets: inherit
  
  # Job 4: Deploy to production (manual trigger only)
  deploy-production:
    name: Deploy to Production
    if: inputs.environment == 'production'
    needs: build
    uses: ./.github/workflows/reusable-cd-$( $DeploymentType.ToLower() ).yml
    with:
      app-name: `${{ env.APP_NAME }}
      version: `${{ needs.build.outputs.artifact-version }}
      environment: 'production'
      skip-health-check: false
      jfrog-repository: `${{ env.JFROG_REPOSITORY }}
      $( if ($DeploymentType -eq 'Azure') {
@"
resource-group: `${{ vars.PROD_RESOURCE_GROUP }}
      resource-name: `${{ vars.PROD_RESOURCE_NAME }}
      resource-type: 'webapp'
"@
      } elseif ($DeploymentType -eq 'AKS') {
@"
aks-cluster-name: `${{ vars.PROD_AKS_CLUSTER }}
      aks-resource-group: `${{ vars.PROD_AKS_RG }}
      acr-name: `${{ vars.ACR_NAME }}
      acr-username: `${{ vars.ACR_USERNAME }}
      kubernetes-namespace: 'production'
"@
      } elseif ($DeploymentType -eq 'IIS') {
@"
iis-server: `${{ vars.PROD_IIS_SERVER }}
      iis-site-name: `${{ vars.PROD_IIS_SITE }}
      iis-app-pool: `${{ vars.PROD_IIS_POOL }}
      iis-deploy-path: `${{ vars.PROD_IIS_PATH }}
"@
      } )
    secrets: inherit
"@
    
    return $template
}

function Get-AzureDevOpsMigrationGuide {
    param(
        [string]$Language,
        [string]$DeploymentType,
        [string]$ProjectName
    )
    
    # Build conditional sections first to avoid nested here-strings
    $serviceConnectionSection = ""
    if ($DeploymentType -eq 'Azure') {
        $serviceConnectionSection = @"
#### Azure Service Connection
``````yaml
# Azure DevOps
azureSubscription: 'Azure-Production'

# GitHub Actions
secrets:
  AZURE_SUBSCRIPTION_ID: `${{ secrets.AZURE_SUBSCRIPTION_ID }}
  AZURE_TENANT_ID: `${{ secrets.AZURE_TENANT_ID }}
  AZURE_CLIENT_ID: `${{ secrets.AZURE_CLIENT_ID }}
  AZURE_CLIENT_SECRET: `${{ secrets.AZURE_CLIENT_SECRET }}
``````
"@
    } elseif ($DeploymentType -eq 'IIS') {
        $serviceConnectionSection = @"
#### IIS Server Connection
``````yaml
# Azure DevOps
connection: 'IIS-Production-Server'

# GitHub Actions
secrets:
  IIS_SERVER: `${{ secrets.IIS_SERVER }}
  IIS_USERNAME: `${{ secrets.IIS_USERNAME }}
  IIS_PASSWORD: `${{ secrets.IIS_PASSWORD }}
``````
"@
    }
    
    $requiredSecretsSection = ""
    if ($DeploymentType -eq 'Azure') {
        $requiredSecretsSection = @"
**Azure Deployment:**
- ``AZURE_SUBSCRIPTION_ID``
- ``AZURE_TENANT_ID``
- ``AZURE_CLIENT_ID``
- ``AZURE_CLIENT_SECRET``
"@
    } elseif ($DeploymentType -eq 'AKS') {
        $requiredSecretsSection = @"
**Azure Kubernetes Service:**
- ``AZURE_SUBSCRIPTION_ID``
- ``AZURE_TENANT_ID``
- ``AZURE_CLIENT_ID``
- ``AZURE_CLIENT_SECRET``
- ``ACR_PASSWORD``
"@
    } elseif ($DeploymentType -eq 'IIS') {
        $requiredSecretsSection = @"
**IIS Deployment:**
- ``IIS_USERNAME``
- ``IIS_PASSWORD``
"@
    }
    
    $envVarsSection = ""
    if ($DeploymentType -eq 'Azure') {
        $envVarsSection = @"
- ``DEV_RESOURCE_GROUP``: Azure resource group
- ``DEV_RESOURCE_NAME``: App Service name
"@
    } elseif ($DeploymentType -eq 'AKS') {
        $envVarsSection = @"
- ``DEV_AKS_CLUSTER``: AKS cluster name
- ``DEV_AKS_RG``: AKS resource group
- ``ACR_NAME``: Container registry name
- ``ACR_USERNAME``: Registry username
"@
    } elseif ($DeploymentType -eq 'IIS') {
        $envVarsSection = @"
- ``DEV_IIS_SERVER``: IIS server address
- ``DEV_IIS_SITE``: IIS site name
- ``DEV_IIS_POOL``: Application pool name
- ``DEV_IIS_PATH``: Deployment path
"@
    }
    
    $troubleshootingSection = ""
    if ($DeploymentType -eq 'Azure') {
        $troubleshootingSection = @"
- Verify service principal has contributor role
- Check subscription ID is correct
- Ensure resource group permissions
"@
    } elseif ($DeploymentType -eq 'IIS') {
        $troubleshootingSection = @"
- Check IIS username has admin rights
- Verify WinRM is enabled on server
- Confirm firewall allows port 5985
"@
    } else {
        $troubleshootingSection = @"
- Verify Kubernetes permissions
- Check service account roles
- Confirm cluster credentials
"@
    }
    
    $langSlug = $Language.ToLower() -replace '\.', ''
    $deploySlug = $DeploymentType.ToLower()
    
    $template = @"
# Azure DevOps to GitHub Actions Migration Guide

This guide helps you migrate your Azure DevOps pipelines to GitHub Actions for the **$ProjectName** project.

## Table of Contents

1. [Overview](#overview)
2. [Concept Mapping](#concept-mapping)
3. [Service Connections to Secrets](#service-connections-to-secrets)
4. [Variable Groups to Environments](#variable-groups-to-environments)
5. [Pipeline Patterns](#pipeline-patterns)
6. [Migration Steps](#migration-steps)
7. [Common Patterns](#common-patterns)
8. [Troubleshooting](#troubleshooting)

## Overview

This migration converts your Azure DevOps pipeline to GitHub Actions using:
- **Reusable Workflows**: Modular CI/CD components
- **GitHub Environments**: Replace Azure DevOps variable groups
- **GitHub Secrets**: Replace Azure DevOps service connections
- **Workflow Dispatch**: Manual deployment triggers

### Key Differences

| Azure DevOps | GitHub Actions |
|--------------|----------------|
| Pipeline | Workflow |
| Job | Job |
| Task | Step |
| Service Connection | Secret |
| Variable Group | Environment + Variables |
| Pipeline Library | Reusable Workflow |
| Release Pipeline | CD Workflow |

## Concept Mapping

### Service Connections â†’ GitHub Secrets

**Azure DevOps Service Connections** are replaced by **GitHub Repository Secrets**.

#### JFrog Service Connection
``````yaml
# Azure DevOps
service: jfrog-artifactory

# GitHub Actions
secrets:
  JFROG_URL: `${{ secrets.JFROG_URL }}
  JFROG_USERNAME: `${{ secrets.JFROG_USERNAME }}
  JFROG_PASSWORD: `${{ secrets.JFROG_PASSWORD }}
``````

$serviceConnectionSection

### Variable Groups â†’ GitHub Environments

**Azure DevOps Variable Groups** are replaced by **GitHub Environment Variables**.

#### Setup GitHub Environments

1. Go to Settings > Environments
2. Create environments: \`development\`, \`staging\`, \`production\`
3. Add environment-specific variables

``````yaml
# Azure DevOps Variable Group
variables:
  - group: prod-config
  - name: ResourceGroup
    value: 'rg-prod'

# GitHub Actions Environment
environment:
  name: production
  # Configure in Settings > Environments > production > Variables
  # Add: RESOURCE_GROUP = rg-prod
``````

### Build/Release Patterns â†’ Workflow Patterns

#### Azure DevOps Multi-Stage Pipeline
``````yaml
# azure-pipelines.yml
stages:
- stage: Build
  jobs:
  - job: BuildJob
    steps:
    - task: DotNetCoreCLI@2
      
- stage: Deploy
  dependsOn: Build
  jobs:
  - deployment: DeployJob
    environment: production
``````

#### GitHub Actions Equivalent
``````yaml
# .github/workflows/build.yml
jobs:
  build:
    uses: ./.github/workflows/reusable-ci-dotnet.yml
    
  deploy:
    needs: build
    uses: ./.github/workflows/reusable-cd-azure.yml
    with:
      environment: production
``````

## Migration Steps

### Step 1: Export Azure DevOps Configuration

1. **Service Connections**
   - Navigate to Project Settings > Service Connections
   - Document all connections (JFrog, Azure, etc.)
   - Note the connection names and types

2. **Variable Groups**
   - Navigate to Pipelines > Library
   - Export all variable groups
   - Document environment-specific values

3.  **Pipeline YAML**
   - Export your existing azure-pipelines.yml
   - Note any custom tasks or scripts

### Step 2: Create GitHub Secrets

Navigate to your GitHub repository > Settings > Secrets and variables > Actions

#### Required Secrets

**JFrog Artifactory:**
- \`JFROG_URL\`
- \`JFROG_USERNAME\`
- \`JFROG_PASSWORD\`

**Security Scanning:**
- \`SONAR_TOKEN\` (optional)
- \`SNYK_TOKEN\` (optional)

$requiredSecretsSection

### Step 3: Create GitHub Environments

1. Go to Settings > Environments
2. Create three environments:
   - **development**
   - **staging**
   - **production**

3. For each environment, add variables:

#### Development Environment
$envVarsSection

*(Repeat for staging and production with appropriate prefixes)*

### Step 4: Setup Workflow Files

Create the following structure in your repository:

``````
.github/
â””â”€â”€ workflows/
    â”œâ”€â”€ build.yml                    # Main orchestrator
    â”œâ”€â”€ reusable-ci-$langSlug.yml      # CI reusable workflow
    â””â”€â”€ reusable-cd-$deploySlug.yml     # CD reusable workflow
``````

### Step 5: Configure Branch Protection

1. Go to Settings > Branches
2. Add protection rule for \`main\` branch:
   - Require pull request reviews
   - Require status checks (build workflow)
   - Require conversation resolution
   - Include administrators

### Step 6: Test the Migration

1. **Test CI Workflow**
   ``````bash
   # Create a feature branch
   git checkout -b feature/test-github-actions
   
   # Make a small change
   echo "# Testing GitHub Actions" >> README.md
   git add README.md
   git commit -m "test: GitHub Actions migration"
   git push origin feature/test-github-actions
   
   # Create PR and verify workflow runs
   ``````

2. **Test CD Workflow**
   - Trigger manual deployment to development
   - Verify artifacts download from JFrog
   - Confirm deployment succeeds
   - Check health endpoints

## Common Patterns

### Pattern 1: Conditional Deployment

**Azure DevOps:**
``````yaml
- stage: Deploy
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
``````

**GitHub Actions:**
``````yaml
deploy:
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
``````

### Pattern 2: Manual Approvals

**Azure DevOps:**
``````yaml
environment:
  name: production
  # Approvals configured in UI
``````

**GitHub Actions:**
``````yaml
environment:
  name: production
  # Configure protection rules in Settings > Environments
``````

### Pattern 3: Artifact Publishing

**Azure DevOps:**
``````yaml
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '`$(Build.ArtifactStagingDirectory)'
    ArtifactName: 'drop'
``````

**GitHub Actions:**
``````yaml
- uses: actions/upload-artifact@v4
  with:
    name: build-artifacts
    path: artifacts/
``````

### Pattern 4: Environment Variables

**Azure DevOps:**
``````yaml
variables:
  buildConfiguration: 'Release'
  
steps:
- script: dotnet build --configuration `$(buildConfiguration)
``````

**GitHub Actions:**
``````yaml
env:
  BUILD_CONFIGURATION: 'Release'
  
steps:
- run: dotnet build --configuration `${{ env.BUILD_CONFIGURATION }}
``````

## Troubleshooting

### Issue: Secrets Not Available

**Problem:** Workflow can't access secrets

**Solution:**
- Verify secrets are created at repository level
- Check secret names match exactly (case-sensitive)
- Ensure workflow has proper permissions

### Issue: Reusable Workflow Not Found

**Problem:** Cannot find reusable workflow

**Solution:**
- Ensure reusable workflows are in \`.github/workflows/\`
- Use correct path: \`./.github/workflows/filename.yml\`
- Verify file names match references

### Issue: Environment Variables Not Available

**Problem:** Environment variables are empty

**Solution:**
- Create environments in Settings > Environments
- Add variables to specific environments
- Reference with \`vars.VARIABLE_NAME\`

### Issue: Deployment Fails with Permission Error

**Problem:** Cannot deploy to target environment

**Solution:**
$troubleshootingSection

## Next Steps

1. âœ… Complete secret migration
2. âœ… Setup GitHub environments
3. âœ… Test CI workflows
4. âœ… Test CD workflows
5. âœ… Configure branch protection
6. âœ… Setup environment protection rules
7. âœ… Train team on GitHub Actions
8. âœ… Decommission Azure DevOps pipelines

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Migrating from Azure Pipelines](https://docs.github.com/en/actions/migrating-to-github-actions/migrating-from-azure-pipelines-to-github-actions)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

## Support

For migration assistance:
1. Review this guide thoroughly
2. Check GitHub Actions documentation
3. Review workflow runs in Actions tab
4. Contact DevOps team for infrastructure questions

---

**Migration Checklist:**
- [ ] Export Azure DevOps configuration
- [ ] Create GitHub secrets
- [ ] Setup GitHub environments
- [ ] Create workflow files
- [ ] Configure branch protection
- [ ] Test CI pipeline
- [ ] Test CD pipeline
- [ ] Train team
- [ ] Go live with GitHub Actions
- [ ] Archive Azure DevOps pipelines
"@
    
    return $template
}


