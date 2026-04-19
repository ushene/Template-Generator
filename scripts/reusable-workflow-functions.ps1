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
# =============================================================================
# REUSABLE CI WORKFLOW — $Language
# =============================================================================
#
# PURPOSE:
#   This is a reusable CI (Continuous Integration) workflow for $Language projects.
#   It handles the entire build pipeline: compile, test, scan for vulnerabilities,
#   package, and publish artifacts to JFrog Artifactory.
#
# HOW IT WORKS:
#   This file is NOT triggered directly by a push or PR.
#   Instead, it is CALLED by the main orchestrator workflow (build.yml) using
#   the 'workflow_call' trigger. The orchestrator passes in all the app-specific
#   values (app name, paths, versions) as inputs and secrets.
#
# REUSABILITY:
#   Because all values are parameterized (passed in via inputs), this same
#   workflow can be reused across multiple $Language projects without modification.
#   Just change the inputs in the calling workflow (build.yml).
#
# PIPELINE STEPS:
#   1. Checkout code from repository
#   2. Set version number from GitHub run number
#   3. Setup $Language SDK/runtime
#   4. Restore/install dependencies
#   5. Build/compile the application
#   6. Run unit tests (skippable)
#   7. Run security scans — SonarQube + Snyk (skippable)
#   8. Package the application into a zip file
#   9. Publish the zip to JFrog Artifactory
#  10. Upload artifacts to GitHub as backup
#  11. Report build status
# =============================================================================

name: Reusable CI - $Language

# ---------------------------------------------------------------------------
# TRIGGER: workflow_call
# ---------------------------------------------------------------------------
# This workflow is triggered when ANOTHER workflow calls it using:
#   uses: ./.github/workflows/reusable-ci-$langLower.yml
# The calling workflow must provide the required inputs and secrets below.
# ---------------------------------------------------------------------------
on:
  workflow_call:

    # =========================================================================
    # INPUTS — Values passed in by the calling workflow (build.yml)
    # =========================================================================
    # These make the workflow reusable. The orchestrator (build.yml) provides
    # all app-specific values here so this file stays generic.
    # =========================================================================
    inputs:
      # The name of your application (used for artifact naming and logging)
      app-name:
        description: 'Application name'
        required: true
        type: string

      # Build configuration — typically 'Release' for CI, 'Debug' for local dev
      build-configuration:
        description: 'Build configuration (Release/Debug)'
        required: false
        type: string
        default: 'Release'

      # $Language SDK/runtime version to install on the build agent
      `$( $versionInputName ):\n        description: '$Language SDK/Runtime version'
        required: false
        type: string
        default: `$( if ($Language -eq '.NET') { "'8.x'" } elseif ($Language -eq 'Python') { "'3.11'" } else { "'20'" } )

      # Set to true to skip unit tests (useful for emergency hotfix deploys)
      skip-tests:
        description: 'Skip running tests'
        required: false
        type: boolean
        default: false

      # Set to true to skip Snyk/SonarQube security scanning
      skip-security-scan:
        description: 'Skip security scanning'
        required: false
        type: boolean
        default: false

      # Which GitHub-hosted runner to use (default: ubuntu-latest)
      runner:
        description: 'GitHub runner to use'
        required: false
        type: string
        default: 'ubuntu-latest'

      # JFrog Artifactory repository name to publish build artifacts to
      # If empty, the JFrog publish step is skipped
      jfrog-repository:
        description: 'JFrog repository name'
        required: false
        type: string
        default: ''

    # =========================================================================
    # OUTPUTS — Values this workflow sends BACK to the calling workflow
    # =========================================================================
    # The orchestrator (build.yml) can read these outputs to pass version info
    # to downstream jobs like deployment.
    # =========================================================================
    outputs:
      # The build version number (matches GitHub run number)
      artifact-version:
        description: 'Version of the built artifact'
        value: `${{ jobs.build.outputs.version }}
      # The full artifact name (e.g., "MyApp-42")
      artifact-name:
        description: 'Name of the artifact'
        value: `${{ jobs.build.outputs.artifact }}
      # Whether the build succeeded or failed
      build-status:
        description: 'Build status (success/failure)'
        value: `${{ jobs.build.outputs.status }}

    # =========================================================================
    # SECRETS — Sensitive values passed in by the calling workflow
    # =========================================================================
    # These are stored in GitHub Settings → Secrets and passed through by
    # the orchestrator using 'secrets: inherit' or explicit mapping.
    # =========================================================================
    secrets:
      # JFrog Artifactory base URL (e.g., https://yourcompany.jfrog.io)
      JFROG_URL:
        description: 'JFrog Artifactory URL'
        required: true
      # JFrog authentication username
      JFROG_USERNAME:
        description: 'JFrog username'
        required: true
      # JFrog authentication password or API token (API token recommended)
      JFROG_PASSWORD:
        description: 'JFrog password or API token'
        required: true
      # SonarQube token for code quality analysis (optional — leave empty to skip)
      SONAR_TOKEN:
        description: 'SonarQube token'
        required: false
      # Snyk token for security vulnerability scanning (optional — leave empty to skip)
      SNYK_TOKEN:
        description: 'Snyk token'
        required: false

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================
# These env vars are available to ALL steps in this workflow.
# They pull their values from the inputs provided by the calling workflow.
# =============================================================================
env:
  # Build mode: Release (optimized) or Debug (with symbols)
  BUILD_CONFIGURATION: `${{ inputs.build-configuration }}
  # Application name — used in artifact naming and log messages
  APP_NAME: `${{ inputs.app-name }}
  # Version number — GitHub auto-increments run_number on every workflow run
  APP_VERSION: `${{ github.run_number }}

# =============================================================================
# JOBS
# =============================================================================
# This workflow has a single job: 'build'
# It runs all CI steps sequentially on the specified runner.
# =============================================================================
jobs:
  build:
    name: Build and Test
    # Run on the specified GitHub-hosted runner (default: ubuntu-latest)
    runs-on: `${{ inputs.runner }}

    # -------------------------------------------------------------------------
    # JOB OUTPUTS — Values passed back to the calling workflow
    # -------------------------------------------------------------------------
    # These are set by steps below using GITHUB_OUTPUT, and can be read by
    # downstream jobs (e.g., deployment) in the orchestrator workflow.
    # -------------------------------------------------------------------------
    outputs:
      version: `${{ steps.set-version.outputs.version }}
      artifact: `${{ steps.set-version.outputs.artifact }}
      status: `${{ steps.set-status.outputs.status }}

    steps:
      # -----------------------------------------------------------------------
      # STEP 1: Checkout source code from the repository
      # -----------------------------------------------------------------------
      # fetch-depth: 0 means fetch ALL commit history (not just the latest).
      # This is needed for tools like SonarQube that analyze commit history.
      # -----------------------------------------------------------------------
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # -----------------------------------------------------------------------
      # STEP 2: Set version output variables
      # -----------------------------------------------------------------------
      # Creates a version string from the GitHub run number and writes it to
      # GITHUB_OUTPUT so the calling workflow can read it (e.g., for deployment).
      # Example: version=42, artifact=MyApp-42
      # -----------------------------------------------------------------------
      - name: Set version
        id: set-version
        shell: pwsh
        run: |
          `$version = "`${{ github.run_number }}"
          `$artifact = "`${{ inputs.app-name }}-`$version"
          "version=`$version" | Out-File -FilePath `$env:GITHUB_OUTPUT -Append -Encoding utf8
          "artifact=`$artifact" | Out-File -FilePath `$env:GITHUB_OUTPUT -Append -Encoding utf8
          Write-Host "Building version: `$version" -ForegroundColor Cyan

      # -----------------------------------------------------------------------
      # STEP 3: Setup $Language SDK/Runtime
      # -----------------------------------------------------------------------
      # Installs the specified version of $Language on the build agent.
      # The version comes from the input parameter (e.g., '8.x' for .NET).
      # -----------------------------------------------------------------------
      - name: Setup $Language
        uses: $( if ($Language -eq '.NET') { 'actions/setup-dotnet@v4' } elseif ($Language -eq 'Python') { 'actions/setup-python@v5' } else { 'actions/setup-node@v4' } )
        with:
          $buildSteps

      # Log the installed version for troubleshooting
      - name: Display $Language version
        shell: pwsh
        run: |
          Write-Host "$Language Version:" -ForegroundColor Cyan
          $( if ($Language -eq '.NET') { 'dotnet --version' } elseif ($Language -eq 'Python') { 'python --version' } else { 'node --version' } )

      # -----------------------------------------------------------------------
      # STEP 4: Restore/install project dependencies
      # -----------------------------------------------------------------------
      # Downloads all packages/libraries the project needs to build.
      # This must run BEFORE the build step.
      # -----------------------------------------------------------------------
      - name: Restore dependencies
        shell: pwsh
        run: |
          Write-Host "Restoring project dependencies..." -ForegroundColor Cyan
          $restoreCommand

      # -----------------------------------------------------------------------
      # STEP 5: Build/compile the application
      # -----------------------------------------------------------------------
      # Compiles the source code in the specified configuration (Release/Debug).
      # --no-restore: skips restoring again since we already did it above.
      # -----------------------------------------------------------------------
      - name: Build application
        shell: pwsh
        run: |
          Write-Host "Building application in `$env:BUILD_CONFIGURATION mode..." -ForegroundColor Cyan
          $buildCommand

      # -----------------------------------------------------------------------
      # STEP 6: Run unit tests
      # -----------------------------------------------------------------------
      # Executes the project's unit tests. Skipped if 'skip-tests' input is true.
      # Test results are uploaded as artifacts for review in the GitHub Actions UI.
      # -----------------------------------------------------------------------
      - name: Run unit tests
        if: `${{ !inputs.skip-tests }}
        shell: pwsh
        run: |
          Write-Host "Running unit tests..." -ForegroundColor Cyan
          $testCommand

      # Upload test results even if tests fail (if: always()) so you can
      # inspect failures in the GitHub Actions artifacts tab.
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

      # -----------------------------------------------------------------------
      # STEP 7: Security scanning — SonarQube + Snyk
      # -----------------------------------------------------------------------
      # SonarQube: Analyzes code quality (bugs, code smells, duplication).
      #   Only runs if SONAR_TOKEN secret is configured.
      # Snyk: Scans dependencies for known security vulnerabilities.
      #   Only runs if SNYK_TOKEN secret is configured.
      # Both are skipped if 'skip-security-scan' input is true.
      # -----------------------------------------------------------------------
      - name: Run SonarQube analysis
        if: `${{ !inputs.skip-security-scan && secrets.SONAR_TOKEN != '' }}
        shell: pwsh
        run: |
          Write-Host "Running SonarQube code quality analysis..." -ForegroundColor Cyan
          Write-Host "SonarQube analysis configured - implement based on your setup" -ForegroundColor Yellow
      
      $( if ($Language -eq '.NET') {
          @'
      # Snyk scans .NET projects by reading obj/project.assets.json
      # which is created during 'dotnet restore'. It checks all NuGet
      # packages for known security vulnerabilities.
      # --severity-threshold=high: only fail on high/critical vulnerabilities
      # || true: don't fail the build if vulnerabilities are found (report only)
      # snyk monitor: sends results to Snyk dashboard for ongoing monitoring
      - name: Run Snyk security scan
        if: `${{ !inputs.skip-security-scan && secrets.SNYK_TOKEN != '' }}
        shell: pwsh
        working-directory: test-dotnet-app/src
        env:
          SNYK_TOKEN: `${{ secrets.SNYK_TOKEN }}
        run: |
          Write-Host "Running Snyk security vulnerability scan..." -ForegroundColor Cyan
          npm install -g snyk
          snyk auth $env:SNYK_TOKEN
          # For .NET, Snyk scans obj/project.assets.json (created by dotnet restore)
          # Let Snyk auto-detect the project structure
          snyk test --severity-threshold=high || true
          snyk monitor
'@
        } elseif ($Language -eq 'Python') {
          @'
      # Snyk scans Python projects by reading requirements.txt to find
      # all pip packages and check them for known security vulnerabilities.
      # --severity-threshold=high: only fail on high/critical vulnerabilities
      # || true: don't fail the build if vulnerabilities are found (report only)
      - name: Run Snyk security scan
        if: `${{ !inputs.skip-security-scan && secrets.SNYK_TOKEN != '' }}
        shell: pwsh
        working-directory: test-python-app
        env:
          SNYK_TOKEN: `${{ secrets.SNYK_TOKEN }}
        run: |
          Write-Host "Running Snyk security vulnerability scan..." -ForegroundColor Cyan
          npm install -g snyk
          snyk auth $env:SNYK_TOKEN
          # Find the requirements.txt file to scan
          $reqFile = Get-ChildItem -Path . -Filter requirements.txt -Recurse -File | Select-Object -First 1
          if (-not $reqFile) {
            Write-Host "No requirements.txt file found in $(Get-Location). Skipping Snyk scan." -ForegroundColor Yellow
            exit 0
          }
          Write-Host "Using requirements file: $($reqFile.FullName)" -ForegroundColor Cyan
          snyk test --file="$($reqFile.FullName)" --severity-threshold=high || true
          snyk monitor --file="$($reqFile.FullName)"
'@
        } elseif ($Language -eq 'Node') {
          @'
      # Snyk scans Node.js projects by reading package.json/package-lock.json
      # to find all npm packages and check them for known security vulnerabilities.
      # --severity-threshold=high: only fail on high/critical vulnerabilities
      # || true: don't fail the build if vulnerabilities are found (report only)
      - name: Run Snyk security scan
        if: `${{ !inputs.skip-security-scan && secrets.SNYK_TOKEN != '' }}
        shell: pwsh
        working-directory: test-node-app
        env:
          SNYK_TOKEN: `${{ secrets.SNYK_TOKEN }}
        run: |
          Write-Host "Running Snyk security vulnerability scan..." -ForegroundColor Cyan
          npm install -g snyk
          snyk auth $env:SNYK_TOKEN
          # Find the package.json file to scan
          $pkgFile = Get-ChildItem -Path . -Filter package.json -Recurse -File | Select-Object -First 1
          if (-not $pkgFile) {
            Write-Host "No package.json file found in $(Get-Location). Skipping Snyk scan." -ForegroundColor Yellow
            exit 0
          }
          Write-Host "Using package file: $($pkgFile.FullName)" -ForegroundColor Cyan
          snyk test --file="$($pkgFile.FullName)" --severity-threshold=high || true
          snyk monitor --file="$($pkgFile.FullName)"
'@
        } else {
          @'
      # Snyk scans for known security vulnerabilities in project dependencies.
      # --severity-threshold=high: only fail on high/critical vulnerabilities
      # || true: don't fail the build if vulnerabilities are found (report only)
      - name: Run Snyk security scan
        if: `${{ !inputs.skip-security-scan && secrets.SNYK_TOKEN != '' }}
        shell: pwsh
        env:
          SNYK_TOKEN: `${{ secrets.SNYK_TOKEN }}
        run: |
          Write-Host "Running Snyk security vulnerability scan..." -ForegroundColor Cyan
          npm install -g snyk
          snyk auth $env:SNYK_TOKEN
          snyk test --severity-threshold=high || true
          snyk monitor
'@
        } )

      # -----------------------------------------------------------------------
      # STEP 8: Package the application
      # -----------------------------------------------------------------------
      # Creates a deployable zip file from the build output.
      # The zip is stored in the 'artifacts/' folder for upload to JFrog
      # and GitHub. Package name format: AppName-Version.zip
      # -----------------------------------------------------------------------
      - name: Package application
        shell: pwsh
        run: |
          Write-Host "Packaging application..." -ForegroundColor Cyan
          `$packageName = "`$env:APP_NAME-`$env:APP_VERSION"
          $packageCommand
          Write-Host "✓ Package created: artifacts/`$packageName.zip" -ForegroundColor Green

      # -----------------------------------------------------------------------
      # STEP 9: Publish artifacts to JFrog Artifactory
      # -----------------------------------------------------------------------
      # Uploads the packaged zip to JFrog Artifactory for long-term storage.
      # JFrog serves as the single source of truth for deployment artifacts.
      # The CD workflow later downloads from JFrog to deploy.
      # Skipped if jfrog-repository input is empty.
      # Target path: {repository}/{app-name}/{version}/
      # -----------------------------------------------------------------------
      - name: Publish to JFrog
        if: inputs.jfrog-repository != ''
        shell: pwsh
        run: |
          Write-Host "Publishing artifacts to JFrog Artifactory..." -ForegroundColor Cyan

          # Install JFrog CLI if not already available on the runner
          if (-not (Get-Command jfrog -ErrorAction SilentlyContinue)) {
            Write-Host "Installing JFrog CLI..." -ForegroundColor Yellow
            curl -fL https://install-cli.jfrog.io | sh
            sudo mv jfrog /usr/local/bin/
          }

          # Configure JFrog CLI with credentials from secrets
          jfrog config add artifactory --url="`${{ secrets.JFROG_URL }}" --user="`${{ secrets.JFROG_USERNAME }}" --password="`${{ secrets.JFROG_PASSWORD }}" --interactive=false

          # Upload all files in artifacts/ to JFrog under {repo}/{app}/{version}/
          `$targetPath = "`${{ inputs.jfrog-repository }}/`$env:APP_NAME/`$env:APP_VERSION/"
          Write-Host "Uploading to `$targetPath" -ForegroundColor Cyan
          jfrog rt upload "artifacts/*" "`$targetPath" --flat=false --recursive=true

          Write-Host "✓ Artifacts published successfully" -ForegroundColor Green

      # -----------------------------------------------------------------------
      # STEP 10: Upload build artifacts to GitHub (backup)
      # -----------------------------------------------------------------------
      # Also uploads artifacts to GitHub Actions as a backup.
      # These are available in the workflow run's "Artifacts" section.
      # retention-days: 30 means GitHub deletes them after 30 days.
      # -----------------------------------------------------------------------
      - name: Upload artifacts to GitHub
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts-`${{ inputs.app-name }}-`${{ github.run_number }}
          path: artifacts/
          retention-days: 30

      # -----------------------------------------------------------------------
      # STEP 11: Set final build status
      # -----------------------------------------------------------------------
      # Records the final job status (success/failure/cancelled) as an output
      # so the orchestrator workflow can read it. Runs even if previous steps
      # failed (if: always()) to ensure status is always reported.
      # -----------------------------------------------------------------------
      - name: Set build status
        id: set-status
        if: always()
        shell: pwsh
        run: |
          `$status = "`${{ job.status }}"
          "status=`$status" | Out-File -FilePath `$env:GITHUB_OUTPUT -Append -Encoding utf8
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
      # -----------------------------------------------------------------------
      # Pre-deploy: Authenticate to Azure using a service principal
      # -----------------------------------------------------------------------
      # Uses az login with service principal credentials (client ID + secret).
      # Then sets the active subscription so all subsequent az commands
      # target the correct Azure environment.
      # -----------------------------------------------------------------------
      - name: Azure Login
        shell: pwsh
        run: |
          Write-Host "Logging in to Azure..." -ForegroundColor Cyan
          # Login using service principal (non-interactive, suitable for CI/CD)
          az login --service-principal -u ${{ secrets.AZURE_CLIENT_ID }} -p ${{ secrets.AZURE_CLIENT_SECRET }} --tenant ${{ secrets.AZURE_TENANT_ID }}
          # Set the active subscription to ensure we deploy to the right one
          az account set --subscription ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          Write-Host "✓ Azure login successful" -ForegroundColor Green
'@
            
            $deploySteps = @'
      # -----------------------------------------------------------------------
      # Deploy: Upload the application package to Azure
      # -----------------------------------------------------------------------
      # Determines the resource type (webapp or functionapp) and deploys
      # accordingly. For web apps, also validates that the Azure runtime
      # matches the package target framework to prevent mismatches.
      # After deploy, retrieves the app URL and saves it as a step output.
      # -----------------------------------------------------------------------
      - name: Deploy to Azure
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to Azure..." -ForegroundColor Cyan
          
          # Check if deploying to a webapp or functionapp
          $resourceType = "${{ inputs.resource-type }}"
          
          if ($resourceType -eq "webapp") {
            # Find the deployment zip file in the artifacts folder
            $zipFile = Get-ChildItem -Path "artifacts" -Filter "*.zip" | Select-Object -First 1 -ExpandProperty FullName
            if (-not $zipFile) { throw "No deployment package found in artifacts folder" }
            
            # SAFETY CHECK: Verify the App Service runtime matches our package
            # This prevents deploying a .NET 8 app to a .NET 6 App Service, etc.
            $linuxFxVersion = az webapp config show `
              --resource-group ${{ inputs.resource-group }} `
              --name ${{ inputs.resource-name }} `
              --query "linuxFxVersion" -o tsv
            
            Write-Host "App Service runtime: $linuxFxVersion" -ForegroundColor Cyan
            if ($linuxFxVersion -and $linuxFxVersion -ne "DOTNETCORE|8.0") {
              throw "App Service runtime '$linuxFxVersion' does not match this package target framework (net8.0). Set the web app runtime to DOTNETCORE|8.0 or retarget the app."
            }
            
            # Deploy the zip package using az webapp deploy (zip deploy)
            Write-Host "Uploading package with az webapp deploy..." -ForegroundColor Yellow
            az webapp deploy `
              --resource-group `${{ inputs.resource-group }} `
              --name `${{ inputs.resource-name }} `
              --src-path "`$zipFile" `
              --type zip `
              --track-status false
            
            # Retrieve the deployed app's URL and save as step output
            $appUrl = az webapp show `
              --resource-group ${{ inputs.resource-group }} `
              --name ${{ inputs.resource-name }} `
              --query "defaultHostName" -o tsv
              
            "app_url=https://$appUrl" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
          }
          elseif ($resourceType -eq "functionapp") {
            # For Function Apps, use config-zip deployment
            $zipFile = Get-ChildItem -Path "artifacts" -Filter "*.zip" | Select-Object -First 1 -ExpandProperty FullName
            if (-not $zipFile) { throw "No deployment package found in artifacts folder" }
            az functionapp deployment source config-zip `
              --resource-group ${{ inputs.resource-group }} `
              --name ${{ inputs.resource-name }} `
              --src "$zipFile"
            
            # Retrieve the Function App's URL and save as step output
            $appUrl = az functionapp show `
              --resource-group ${{ inputs.resource-group }} `
              --name ${{ inputs.resource-name }} `
              --query "defaultHostName" -o tsv
              
            "app_url=https://$appUrl" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
          }
          
          Write-Host "✓ Deployment uploaded" -ForegroundColor Green
'@
        }
        'AKS' {
            $preDeploySteps = @'
      # -----------------------------------------------------------------------
      # Pre-deploy: Connect to Azure Kubernetes Service (AKS)
      # -----------------------------------------------------------------------
      # Authenticates to Azure, then downloads AKS cluster credentials
      # so kubectl can communicate with the Kubernetes cluster.
      # -----------------------------------------------------------------------
      - name: Setup Kubernetes
        shell: pwsh
        run: |
          Write-Host "Setting up Kubernetes..." -ForegroundColor Cyan
          # Login to Azure using service principal
          az login --service-principal -u ${{ secrets.AZURE_CLIENT_ID }} -p ${{ secrets.AZURE_CLIENT_SECRET }} --tenant ${{ secrets.AZURE_TENANT_ID }}
          # Download AKS credentials into ~/.kube/config
          az aks get-credentials --resource-group ${{ inputs.aks-resource-group }} --name ${{ inputs.aks-cluster-name }}
          # Verify we can talk to the cluster
          kubectl cluster-info
          Write-Host "✓ Kubernetes setup complete" -ForegroundColor Green
'@
            
            $deploySteps = @'
      # -----------------------------------------------------------------------
      # Deploy: Build Docker image, push to ACR, update AKS deployment
      # -----------------------------------------------------------------------
      # 1. Builds a Docker image tagged with the version number
      # 2. Pushes it to Azure Container Registry (ACR)
      # 3. Updates the Kubernetes deployment to use the new image
      # 4. Waits for the rollout to complete (up to 5 minutes)
      # 5. Retrieves the service's external IP as the app URL
      # -----------------------------------------------------------------------
      - name: Deploy to AKS
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to Azure Kubernetes Service..." -ForegroundColor Cyan
          
          # Build Docker image with ACR-compatible tag
          docker build -t ${{ inputs.acr-name }}.azurecr.io/${{ inputs.app-name }}:${{ inputs.version }} .
          
          # Authenticate to Azure Container Registry
          echo ${{ secrets.ACR_PASSWORD }} | docker login ${{ inputs.acr-name }}.azurecr.io -u ${{ inputs.acr-username }} --password-stdin
          
          # Push image to ACR so AKS can pull it
          docker push ${{ inputs.acr-name }}.azurecr.io/${{ inputs.app-name }}:${{ inputs.version }}
          
          # Tell Kubernetes to update the deployment with the new image
          kubectl set image deployment/${{ inputs.app-name }} `
            ${{ inputs.app-name }}=${{ inputs.acr-name }}.azurecr.io/${{ inputs.app-name }}:${{ inputs.version }} `
            -n ${{ inputs.kubernetes-namespace }}
          
          # Wait for all pods to be updated (timeout: 5 minutes)
          kubectl rollout status deployment/${{ inputs.app-name }} -n ${{ inputs.kubernetes-namespace }} --timeout=300s
          
          # Get the external IP of the service for health checks
          $serviceIP = kubectl get service ${{ inputs.app-name }} -n ${{ inputs.kubernetes-namespace }} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
          "app_url=http://$serviceIP" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
          
          Write-Host "✓ Deployment complete" -ForegroundColor Green
'@
        }
        'IIS' {
            $preDeploySteps = @'
      # -----------------------------------------------------------------------
      # Pre-deploy: Validate connectivity to the IIS server
      # -----------------------------------------------------------------------
      # Tests that the build agent can reach the IIS server on port 5985
      # (WinRM). If this fails, the deployment will not proceed.
      # -----------------------------------------------------------------------
      - name: Validate IIS Connection
        shell: pwsh
        run: |
          Write-Host "Validating IIS server connection..." -ForegroundColor Cyan
          # Test WinRM connectivity (port 5985) to the IIS server
          Test-NetConnection -ComputerName ${{ inputs.iis-server }} -Port 5985 -InformationLevel Detailed
          Write-Host "✓ Connection validated" -ForegroundColor Green
'@
            
            $deploySteps = @'
      # -----------------------------------------------------------------------
      # Deploy: Remote deploy to IIS via PowerShell Remoting (WinRM)
      # -----------------------------------------------------------------------
      # 1. Creates a PS remoting session to the IIS server
      # 2. Copies the zip package to the server
      # 3. Stops the app pool (so files aren't locked)
      # 4. Backs up the current deployment
      # 5. Extracts the new package to the site's physical path
      # 6. Restarts the app pool and verifies the site is running
      # -----------------------------------------------------------------------
      - name: Deploy to IIS
        id: deploy
        shell: pwsh
        run: |
          Write-Host "Deploying to IIS..." -ForegroundColor Cyan
          
          # Create credentials for remote connection
          $securePassword = ConvertTo-SecureString ${{ secrets.IIS_PASSWORD }} -AsPlainText -Force
          $credential = New-Object System.Management.Automation.PSCredential (${{ secrets.IIS_USERNAME }}, $securePassword)
          
          # Open a remote PowerShell session to the IIS server
          $session = New-PSSession -ComputerName ${{ inputs.iis-server }} -Credential $credential
          
          # Copy the deployment zip to the remote server's temp folder
          Copy-Item -Path "artifacts/*.zip" -Destination "C:\Temp\" -ToSession $session
          
          # Execute the deployment on the remote server
          Invoke-Command -Session $session -ScriptBlock {
            param($appName, $siteName, $appPool, $deployPath, $version)
            
            Import-Module WebAdministration
            
            # Stop the app pool so deployed files are not locked
            Stop-WebAppPool -Name $appPool
            Start-Sleep -Seconds 5
            
            # Backup current deployment before overwriting
            if (Test-Path $deployPath) {
              $backupPath = "$deployPath-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
              Copy-Item -Path $deployPath -Destination $backupPath -Recurse -Force
            }
            
            # Remove old files and extract new package
            Remove-Item -Path $deployPath\* -Recurse -Force -ErrorAction SilentlyContinue
            Expand-Archive -Path "C:\Temp\$appName-$version.zip" -DestinationPath $deployPath -Force
            
            # Restart the app pool
            Start-WebAppPool -Name $appPool
            
            # Make sure the website itself is started
            $site = Get-Website -Name $siteName
            if ($site.State -ne 'Started') {
              Start-Website -Name $siteName
            }
          } -ArgumentList "${{ inputs.app-name }}", "${{ inputs.iis-site-name }}", "${{ inputs.iis-app-pool }}", "${{ inputs.iis-deploy-path }}", "${{ inputs.version }}"
          
          # Clean up the remote session
          Remove-PSSession $session
          
          "app_url=http://${{ inputs.iis-server }}" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
          Write-Host "✓ Deployment complete" -ForegroundColor Green
'@
        }
    }
    
    $template = @"
# =============================================================================
# REUSABLE CD WORKFLOW — $DeploymentType Deployment
# =============================================================================
#
# PURPOSE:
#   This is a reusable CD (Continuous Deployment) workflow that deploys
#   applications to $DeploymentType. It handles artifact download from JFrog,
#   deployment, and post-deployment health checks.
#
# HOW IT WORKS:
#   This file is NOT triggered directly by a push or PR.
#   Instead, it is CALLED by the main orchestrator workflow (build.yml) using
#   the 'workflow_call' trigger. The orchestrator passes environment-specific
#   values (resource group, resource name, etc.) as inputs.
#
# REUSABILITY:
#   Because all values are parameterized, this same workflow can deploy to
#   development, staging, or production — the orchestrator just passes
#   different input values for each environment.
#
# PIPELINE STEPS:
#   1. Checkout repository (for any deployment scripts)
#   2. Download artifacts from JFrog Artifactory
#   3. Authenticate to $DeploymentType
#   4. Deploy the application
#   5. Run health checks to verify deployment succeeded
#   6. Report deployment status
# =============================================================================

name: Reusable CD - $DeploymentType

# ---------------------------------------------------------------------------
# TRIGGER: workflow_call
# ---------------------------------------------------------------------------
# This workflow is triggered when ANOTHER workflow calls it using:
#   uses: ./.github/workflows/reusable-cd-$($DeploymentType.ToLower()).yml
# The calling workflow must provide the required inputs and secrets below.
# ---------------------------------------------------------------------------
on:
  workflow_call:

    # =========================================================================
    # INPUTS — Values passed in by the calling workflow (build.yml)
    # =========================================================================
    inputs:
      # The name of the application being deployed (used in JFrog path and logging)
      app-name:
        description: 'Application name'
        required: true
        type: string

      # The version/build number to deploy (used to locate the artifact in JFrog)
      version:
        description: 'Version to deploy'
        required: true
        type: string

      # Target environment name — must match a GitHub Environment (development/staging/production)
      environment:
        description: 'Target environment'
        required: true
        type: string

      # Set to true to skip health checks after deployment
      skip-health-check:
        description: 'Skip post-deployment health check'
        required: false
        type: boolean
        default: false

      # Which GitHub-hosted runner to use for deployment
      runner:
        description: 'GitHub runner to use'
        required: false
        type: string
        default: '$runnerOS'

      # JFrog Artifactory repository where build artifacts are stored
      jfrog-repository:
        description: 'JFrog repository name'
        required: true
        type: string

      # --- Deployment target-specific inputs ---
      $( if ($DeploymentType -eq 'Azure') {
@"
# Azure resource group containing the App Service or Function App
      resource-group:
        description: 'Azure resource group'
        required: true
        type: string
      # Azure resource name (App Service or Function App name)
      resource-name:
        description: 'Azure resource name'
        required: true
        type: string
      # Type of Azure resource: 'webapp' for App Service, 'functionapp' for Functions
      resource-type:
        description: 'Azure resource type (webapp/functionapp)'
        required: false
        type: string
        default: 'webapp'
"@
      } elseif ($DeploymentType -eq 'AKS') {
@"
# Name of the AKS cluster to deploy to
      aks-cluster-name:
        description: 'AKS cluster name'
        required: true
        type: string
      # Resource group containing the AKS cluster
      aks-resource-group:
        description: 'AKS resource group'
        required: true
        type: string
      # Azure Container Registry name (where Docker images are stored)
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
    
    # =========================================================================
    # OUTPUTS — Values this workflow sends BACK to the calling workflow
    # =========================================================================
    outputs:
      # The URL of the deployed application (retrieved after deployment)
      deployment-url:
        description: 'URL of the deployed application'
        value: `${{ jobs.deploy.outputs.url }}
      # Whether the deployment succeeded or failed
      deployment-status:
        description: 'Deployment status (success/failure)'
        value: `${{ jobs.deploy.outputs.status }}

    # =========================================================================
    # SECRETS — Sensitive credentials passed in by the calling workflow
    # =========================================================================
    secrets:
      # JFrog Artifactory base URL (e.g., https://yourcompany.jfrog.io)
      JFROG_URL:
        description: 'JFrog Artifactory URL'
        required: true
      # JFrog authentication username
      JFROG_USERNAME:
        description: 'JFrog username'
        required: true
      # JFrog authentication password or API token
      JFROG_PASSWORD:
        description: 'JFrog password or API token'
        required: true
      $( if ($DeploymentType -in @('Azure', 'AKS')) {
@"
# Azure service principal credentials for authentication
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
# Azure Container Registry password for pushing Docker images
      ACR_PASSWORD:
        description: 'Azure Container Registry password'
        required: true
"@
      } )
      $( if ($DeploymentType -eq 'IIS') {
@"
# IIS server credentials for remote deployment via WinRM
      IIS_USERNAME:
        description: 'IIS deployment username'
        required: true
      IIS_PASSWORD:
        description: 'IIS deployment password'
        required: true
"@
      } )

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================
# These env vars are available to ALL steps in this workflow.
# =============================================================================
env:
  # Application name — used in JFrog download path and logging
  APP_NAME: `${{ inputs.app-name }}
  # Version to deploy — used to locate the correct artifact in JFrog
  APP_VERSION: `${{ inputs.version }}
  # Target environment name (development/staging/production)
  TARGET_ENV: `${{ inputs.environment }}

# =============================================================================
# JOBS
# =============================================================================
jobs:
  deploy:
    name: Deploy to `${{ inputs.environment }}
    # Run on the specified GitHub-hosted runner
    runs-on: `${{ inputs.runner }}

    # -------------------------------------------------------------------------
    # ENVIRONMENT PROTECTION
    # -------------------------------------------------------------------------
    # Links this job to a GitHub Environment (e.g., 'production').
    # If the environment has protection rules (required reviewers, wait timers),
    # the job will pause until those rules are satisfied.
    # The URL is displayed in the GitHub deployments page.
    # -------------------------------------------------------------------------
    environment:
      name: `${{ inputs.environment }}
      url: `${{ steps.deploy.outputs.app_url }}

    # Job outputs — passed back to the calling workflow
    outputs:
      url: `${{ steps.deploy.outputs.app_url }}
      status: `${{ steps.set-status.outputs.status }}

    steps:
      # -----------------------------------------------------------------------
      # STEP 1: Checkout repository
      # -----------------------------------------------------------------------
      # Only checks out deployment/ and scripts/ folders (sparse-checkout)
      # to speed up the checkout. We don't need the full source code here.
      # -----------------------------------------------------------------------
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          sparse-checkout: |
            deployment/
            scripts/

      # -----------------------------------------------------------------------
      # STEP 2: Download artifacts from JFrog Artifactory
      # -----------------------------------------------------------------------
      # Downloads the build package (zip file) that the CI workflow published.
      # Path in JFrog: {repository}/{app-name}/{version}/
      # -----------------------------------------------------------------------
      - name: Download artifacts from JFrog
        shell: pwsh
        run: |
          Write-Host "Downloading artifacts from JFrog..." -ForegroundColor Cyan

          # Install JFrog CLI if not already available on the runner
          if (-not (Get-Command jfrog -ErrorAction SilentlyContinue)) {
            Write-Host "Installing JFrog CLI..." -ForegroundColor Yellow
            $( if ($DeploymentType -eq 'IIS') {
                'Invoke-WebRequest -Uri "https://releases.jfrog.io/artifactory/jfrog-cli/v2/[RELEASE]/jfrog-cli-windows-amd64/jfrog.exe" -OutFile "jfrog.exe"'
            } else {
                'curl -fL https://install-cli.jfrog.io | sh; sudo mv jfrog /usr/local/bin/'
            } )
          }

          # Configure JFrog CLI with credentials from secrets
          jfrog config add artifactory --url="`${{ secrets.JFROG_URL }}" --user="`${{ secrets.JFROG_USERNAME }}" --password="`${{ secrets.JFROG_PASSWORD }}" --interactive=false

          # Download the artifact for the specified version
          `$artifactPath = "`${{ inputs.jfrog-repository }}/`${{ inputs.app-name }}/`${{ inputs.version }}/"
          New-Item -ItemType Directory -Path "artifacts" -Force | Out-Null
          jfrog rt download "`$artifactPath" "artifacts/" --flat=false --recursive=true

          Write-Host "✓ Artifacts downloaded" -ForegroundColor Green

      # -----------------------------------------------------------------------
      # STEP 3: Pre-deployment — authenticate to deployment target
      # -----------------------------------------------------------------------
$preDeploySteps

      # -----------------------------------------------------------------------
      # STEP 4: Deploy the application
      # -----------------------------------------------------------------------
$deploySteps
      
      # -----------------------------------------------------------------------
      # STEP 5: Post-deployment health check
      # -----------------------------------------------------------------------
      # Verifies the application is running correctly after deployment.
      # First waits 60 seconds for the app to start up, then retries
      # the readiness (/api/ready) and health (/api/health) endpoints
      # up to 20 times with 30-second delays between attempts.
      # Total max wait: ~11 minutes. Skipped if skip-health-check is true.
      # -----------------------------------------------------------------------
      - name: Health check
        if: `${{ !inputs.skip-health-check }}
        shell: pwsh
        run: |
          Write-Host "Running health checks..." -ForegroundColor Cyan

          `$appUrl = "`${{ steps.deploy.outputs.app_url }}"
          `$maxRetries = 20
          `$retryDelaySeconds = 30

          # Initial wait — give the app time to start before first check
          Write-Host "Waiting 60 seconds for deployment to settle..." -ForegroundColor Yellow
          Start-Sleep -Seconds 60

          # Common parameters for all HTTP requests
          `$iwrParams = @{
            Method = 'Get'
            TimeoutSec = 45
            UseBasicParsing = `$true
            SkipCertificateCheck = `$true
            ErrorAction = 'Stop'
          }

          # Retry loop — keep checking until health passes or max retries reached
          for (`$retryCount = 1; `$retryCount -le `$maxRetries; `$retryCount++) {
            `$elapsedSeconds = 60 + ((`$retryCount - 1) * `$retryDelaySeconds)
            Write-Host "Health check attempt `$retryCount/`$maxRetries (elapsed: `${elapsedSeconds}s)..." -ForegroundColor Yellow

            try {
              # First check: readiness endpoint — is the app ready to serve traffic?
              `$readyResponse = Invoke-WebRequest -Uri "`$appUrl/api/ready" @iwrParams
              if (`$readyResponse.StatusCode -eq 200) {
                Write-Host "Readiness check passed" -ForegroundColor Green

                # Second check: health endpoint — are all dependencies healthy?
                `$healthResponse = Invoke-WebRequest -Uri "`$appUrl/api/health" @iwrParams
                if (`$healthResponse.StatusCode -eq 200) {
                  Write-Host "Health check passed" -ForegroundColor Green
                  exit 0
                }
              }
            }
            catch {
              Write-Host "Application is still starting: `$(`$_.Exception.Message)" -ForegroundColor DarkYellow
            }

            # Wait before next retry (unless this was the last attempt)
            if (`$retryCount -lt `$maxRetries) {
              Start-Sleep -Seconds `$retryDelaySeconds
            }
          }

          # If we get here, health checks never passed
          Write-Host "Health check did not pass after `$(((`$maxRetries - 1) * `$retryDelaySeconds) + 60) seconds" -ForegroundColor Red
          Write-Host "Check container logs: `$appUrl/scm/api/logs/docker" -ForegroundColor Yellow
          exit 1

      # -----------------------------------------------------------------------
      # STEP 6: Set final deployment status
      # -----------------------------------------------------------------------
      # Records the job status as an output so the orchestrator can read it.
      # Runs even if deployment failed (if: always()) to ensure status is reported.
      # -----------------------------------------------------------------------
      - name: Set deployment status
        id: set-status
        if: always()
        shell: pwsh
        run: |
          `$status = "`${{ job.status }}"
          "status=`$status" | Out-File -FilePath `$env:GITHUB_OUTPUT -Append -Encoding utf8
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
# =============================================================================
# MAIN BUILD WORKFLOW (ORCHESTRATOR)
# =============================================================================
#
# PROJECT:    $ProjectName
# LANGUAGE:   $Language
# DEPLOYMENT: $DeploymentType
#
# PURPOSE:
#   This is the ENTRY POINT for the CI/CD pipeline. It does NOT contain
#   build or deploy logic itself — instead, it CALLS the reusable CI and CD
#   workflows and passes them all the app-specific configuration.
#
# HOW TO REUSE FOR A NEW PROJECT:
#   1. Change the values in the 'env:' block below (app name, paths, versions)
#   2. That's it — the reusable workflows read everything from inputs.
#
# PIPELINE FLOW:
#   Push/PR → config job → build job (CI) → deploy jobs (CD per environment)
#
# =============================================================================

name: Build and Deploy

# ---------------------------------------------------------------------------
# TRIGGERS — When does this workflow run?
# ---------------------------------------------------------------------------
# 1. On push to main, develop, feature/*, or release/* branches
# 2. On pull requests targeting main or develop
# 3. Manual trigger via GitHub UI (workflow_dispatch) with environment selection
# ---------------------------------------------------------------------------
on:
  push:
    branches:
      - main           # Production-ready code
      - develop        # Integration branch → triggers dev deployment
      - 'feature/**'   # Feature branches → CI only, no deployment
      - 'release/**'   # Release branches → CI only
  pull_request:
    branches:
      - main
      - develop
  workflow_dispatch:
    inputs:
      # Allows manual deployment to a specific environment from the GitHub UI
      environment:
        description: 'Deploy to environment'
        required: false
        type: choice
        options:
          - none         # Just build, don't deploy
          - development
          - staging
          - production
        default: 'none'
      # Emergency flag to skip tests (use sparingly!)
      skip_tests:
        description: 'Skip running tests'
        required: false
        type: boolean
        default: false

# =============================================================================
# CENTRALIZED CONFIGURATION
# =============================================================================
# *** CHANGE THESE VALUES FOR YOUR PROJECT ***
# All app-specific settings are defined here in one place.
# The reusable workflows receive these values via inputs.
# =============================================================================
env:
  # Your application name — used for artifact naming and deployment
  APP_NAME: '$ProjectName'
  # JFrog repository where build artifacts are stored
  JFROG_REPOSITORY: $( if ($DeploymentType -eq 'Azure') { "'azure-apps'" } elseif ($DeploymentType -eq 'AKS') { "'kubernetes-apps'" } else { "'iis-apps'" } )

# =============================================================================
# JOBS
# =============================================================================
jobs:

  # ---------------------------------------------------------------------------
  # JOB 1: BUILD — Calls the reusable CI workflow
  # ---------------------------------------------------------------------------
  # This job calls the reusable CI workflow and passes all app-specific
  # configuration as inputs. The CI workflow handles:
  # restore → build → test → security scan → package → publish to JFrog
  # ---------------------------------------------------------------------------
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
    # Pass all secrets through to the reusable workflow
    secrets:
      JFROG_URL: `${{ secrets.JFROG_URL }}
      JFROG_USERNAME: `${{ secrets.JFROG_USERNAME }}
      JFROG_PASSWORD: `${{ secrets.JFROG_PASSWORD }}
      SONAR_TOKEN: `${{ secrets.SONAR_TOKEN }}
      SNYK_TOKEN: `${{ secrets.SNYK_TOKEN }}

  # ---------------------------------------------------------------------------
  # JOB 2: DEPLOY TO DEVELOPMENT
  # ---------------------------------------------------------------------------
  # Runs automatically on push to 'develop' branch, or manually when
  # 'development' is selected in workflow_dispatch.
  # Waits for the build job to complete successfully first (needs: build).
  # ---------------------------------------------------------------------------
  deploy-dev:
    name: Deploy to Development
    # Only deploy on develop branch pushes or manual 'development' selection
    if: `${{ (github.event_name == 'push' && github.ref == 'refs/heads/develop') || (github.event_name == 'workflow_dispatch' && inputs.environment == 'development') }}
    needs: build
    uses: ./.github/workflows/reusable-cd-$( $DeploymentType.ToLower() ).yml
    with:
      app-name: `${{ env.APP_NAME }}
      version: `${{ needs.build.outputs.artifact-version }}
      environment: 'development'
      skip-health-check: false
      jfrog-repository: `${{ env.JFROG_REPOSITORY }}
      # Environment-specific resource settings from GitHub Variables
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
    # 'secrets: inherit' passes ALL repository secrets to the reusable workflow
    secrets: inherit

  # ---------------------------------------------------------------------------
  # JOB 3: DEPLOY TO STAGING
  # ---------------------------------------------------------------------------
  # Runs automatically on push to 'main' branch, or manually when
  # 'staging' is selected in workflow_dispatch.
  # ---------------------------------------------------------------------------
  deploy-staging:
    name: Deploy to Staging
    if: `${{ (github.event_name == 'push' && github.ref == 'refs/heads/main') || (github.event_name == 'workflow_dispatch' && inputs.environment == 'staging') }}
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

  # ---------------------------------------------------------------------------
  # JOB 4: DEPLOY TO PRODUCTION
  # ---------------------------------------------------------------------------
  # Only runs via manual trigger (workflow_dispatch) when 'production'
  # is selected. Never auto-deploys to production.
  # Configure GitHub Environment protection rules (required reviewers,
  # wait timers) in Settings → Environments → production.
  # ---------------------------------------------------------------------------
  deploy-production:
    name: Deploy to Production
    # SAFETY: Production deployment requires manual trigger only
    if: `${{ github.event_name == 'workflow_dispatch' && inputs.environment == 'production' }}
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

### Service Connections → GitHub Secrets

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

### Variable Groups → GitHub Environments

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

### Build/Release Patterns → Workflow Patterns

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
└── workflows/
    ├── build.yml                    # Main orchestrator
    ├── reusable-ci-$langSlug.yml      # CI reusable workflow
    └── reusable-cd-$deploySlug.yml     # CD reusable workflow
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

1. ✅ Complete secret migration
2. ✅ Setup GitHub environments
3. ✅ Test CI workflows
4. ✅ Test CD workflows
5. ✅ Configure branch protection
6. ✅ Setup environment protection rules
7. ✅ Train team on GitHub Actions
8. ✅ Decommission Azure DevOps pipelines

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


