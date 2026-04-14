# Setup Instructions - Fix "Script Not Found" Error

## 🚨 Issue
The workflow can't find `generate-templates.ps1` because the scripts haven't been pushed to your GitHub repository yet.

## ✅ Solution - Push Files to GitHub

### Step 1: Initialize Git (if not already done)

```powershell
# Navigate to your project folder
cd "c:\Users\lenoy\OneDrive\Desktop\Template Generator"

# Initialize git repository
git init

# Check status
git status
```

### Step 2: Add All Files

```powershell
# Add all files to git
git add .

# Verify files are staged
git status

# You should see:
# - .github/workflows/template-generator.yml
# - scripts/generate-templates.ps1
# - scripts/template-functions.ps1
# - README.md
# - etc.
```

### Step 3: Commit Files

```powershell
# Commit with a message
git commit -m "Add Template Generator Tool with scripts"
```

### Step 4: Create GitHub Repository

#### Option A: Using GitHub Web Interface

1. **Go to GitHub**: https://github.com/new
2. **Repository name**: `template-generator` (or whatever you want)
3. **Description**: "CI/CD Template Generator Tool"
4. **Visibility**: Choose Public or Private
5. **DO NOT** initialize with README, .gitignore, or license
6. **Click**: "Create repository"

#### Option B: Using GitHub CLI

```powershell
# Install GitHub CLI first (if not installed)
winget install GitHub.cli

# Login to GitHub
gh auth login

# Create repository
gh repo create template-generator --private --source=. --remote=origin --push
```

### Step 5: Push to GitHub (Manual Method)

If you created the repo via web interface:

```powershell
# Add remote (replace YOUR-USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR-USERNAME/template-generator.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 6: Verify Files Are on GitHub

1. Go to your repository on GitHub
2. You should see:
   ```
   .github/workflows/template-generator.yml
   scripts/generate-templates.ps1
   scripts/template-functions.ps1
   README.md
   QUICKSTART.md
   etc.
   ```

### Step 7: Run the Workflow

1. **Go to**: Actions tab in your GitHub repository
2. **Click**: "Template Generator Tool"
3. **Click**: "Run workflow"
4. **Fill in** the form and click "Run workflow"

---

## 🔍 What I Fixed in the Workflow

### Changes Made:

1. **Added verification step** - Checks if scripts exist before running
2. **Better error messages** - Shows which files are missing
3. **Absolute path** - Uses `${{ github.workspace }}` for reliability
4. **File listing** - Shows all available files if scripts are missing

### Updated Workflow Structure:

```yaml
steps:
  - Checkout repository
  - Setup PowerShell
  - Verify script files ← NEW! Checks if files exist
  - Generate CI/CD Templates ← FIXED! Uses absolute path
  - Upload Generated Templates
  - Display Summary
```

---

## 📋 Quick Checklist

Before running the workflow, verify:

- [ ] All files are in local folder
- [ ] Git repository is initialized
- [ ] Files are committed to git
- [ ] GitHub repository is created
- [ ] Files are pushed to GitHub
- [ ] You can see scripts/ folder on GitHub
- [ ] Workflow file is in .github/workflows/

---

## 🐛 Troubleshooting

### "fatal: not a git repository"

```powershell
# Initialize git first
git init
git add .
git commit -m "Initial commit"
```

### "remote origin already exists"

```powershell
# Remove old remote and add new one
git remote remove origin
git remote add origin https://github.com/YOUR-USERNAME/template-generator.git
```

### "Permission denied (publickey)"

```powershell
# Use HTTPS instead of SSH
git remote set-url origin https://github.com/YOUR-USERNAME/template-generator.git

# Or configure SSH keys:
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh
```

### Files still not found in workflow

```powershell
# Make sure you pushed to the correct branch
git branch  # Check current branch
git push origin main  # Push to main branch

# Verify on GitHub that files are there
```

---

## 🎯 Alternative: Test Locally First

If you want to test before pushing to GitHub:

```powershell
# Run the script locally
cd "c:\Users\lenoy\OneDrive\Desktop\Template Generator"

.\scripts\generate-templates.ps1 `
  -ApplicationType "Azure Function Apps" `
  -Language ".NET" `
  -DeploymentType "Azure" `
  -ProjectName "test-app"

# Check generated files
ls generated\
```

---

## 📞 Need Help?

If you're still getting errors:

1. **Check the new verification step** output in GitHub Actions
2. It will show exactly which files are missing
3. It will list all available files in the repository

The updated workflow now provides much better error messages!
