# ============================================
# GitHub Deployment Script for StaticBlazorSnomed
# ============================================
# This script commits and pushes changes to GitHub
# Repository: https://github.com/KhanInformatics/StaticBlazorSnomed.git
# ============================================

param(
    [string]$CommitMessage = "Update: Added 2024-25 usage data column and improvements"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  StaticBlazorSnomed - GitHub Deployment" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project root
$ProjectRoot = "o:\GitHub\StaticBlazorSnomed"
Write-Host "📁 Navigating to project root: $ProjectRoot" -ForegroundColor Yellow
cd $ProjectRoot

# Check if git is initialized
if (-not (Test-Path ".git")) {
    Write-Host "⚠️  Git repository not initialized. Initializing..." -ForegroundColor Yellow
    git init
    git remote add origin https://github.com/KhanInformatics/StaticBlazorSnomed.git
    Write-Host "✅ Git initialized and remote added" -ForegroundColor Green
} else {
    Write-Host "✅ Git repository already initialized" -ForegroundColor Green
}

# Check git status
Write-Host ""
Write-Host "📊 Current Git Status:" -ForegroundColor Yellow
git status --short

# Stage all changes
Write-Host ""
Write-Host "📦 Staging all changes..." -ForegroundColor Yellow
git add .

# Show what will be committed
Write-Host ""
Write-Host "📋 Files to be committed:" -ForegroundColor Yellow
git status --short

# Commit changes
Write-Host ""
Write-Host "💾 Committing changes with message: '$CommitMessage'" -ForegroundColor Yellow
git commit -m $CommitMessage

# Show recent commits
Write-Host ""
Write-Host "📜 Recent commits:" -ForegroundColor Yellow
git log --oneline -5

# Push to GitHub
Write-Host ""
Write-Host "🚀 Pushing to GitHub (main branch)..." -ForegroundColor Yellow
$pushResult = git push origin main 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  ✅ Successfully deployed to GitHub!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📍 Repository: https://github.com/KhanInformatics/StaticBlazorSnomed" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Go to Azure Portal: https://portal.azure.com" -ForegroundColor White
    Write-Host "2. Create a Static Web App and connect to this GitHub repo" -ForegroundColor White
    Write-Host "3. Configure build settings:" -ForegroundColor White
    Write-Host "   - App location: /StaticBlazorSnomed" -ForegroundColor Gray
    Write-Host "   - Output location: wwwroot" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "  ❌ Push failed!" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Red
    Write-Host $pushResult -ForegroundColor Red
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "1. Ensure you're authenticated: git config --global user.name 'Your Name'" -ForegroundColor White
    Write-Host "2. Check credentials: git credential-manager" -ForegroundColor White
    Write-Host "3. Pull first if needed: git pull origin main --rebase" -ForegroundColor White
    exit 1
}
