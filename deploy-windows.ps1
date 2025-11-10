# GitHub Actions Runner Deployment Script for Windows
# Run this in PowerShell on the Windows VM

# Requires PowerShell 5.0 or higher
#Requires -Version 5.0

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "GitHub Actions Runner Deployment (Windows)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

function Write-Status {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
}

# Check if .env.windows file exists
if (-not (Test-Path ".env.windows")) {
    Write-ErrorMsg ".env.windows file not found!"
    Write-Host "Please copy .env.windows.example to .env.windows and configure it:"
    Write-Host "  Copy-Item .env.windows.example .env.windows"
    Write-Host "  notepad .env.windows"
    exit 1
}

Write-Status ".env.windows file found"

# Check if GITHUB_PAT is configured
$envContent = Get-Content ".env.windows" -Raw
if ($envContent -match "your_github_personal_access_token_here") {
    Write-ErrorMsg "GITHUB_PAT not configured in .env.windows file!"
    Write-Host "Please edit .env.windows and set your GitHub Personal Access Token"
    exit 1
}

Write-Status "GITHUB_PAT appears to be configured"

# Check Docker Desktop is running
try {
    docker info | Out-Null
    Write-Status "Docker Desktop is running"
} catch {
    Write-ErrorMsg "Docker Desktop is not running or not installed!"
    Write-Host "Please start Docker Desktop and try again"
    exit 1
}

# Check available disk space (C: drive)
$disk = Get-PSDrive C
$freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)
if ($freeSpaceGB -lt 20) {
    Write-Warning "Available disk space on C: is less than 20GB (${freeSpaceGB}GB)"
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit 1
    }
} else {
    Write-Status "Sufficient disk space available (${freeSpaceGB}GB)"
}

# Validate docker-compose file
Write-Host ""
Write-Host "Validating docker-compose.windows.yml..."
try {
    docker-compose -f docker-compose.windows.yml config | Out-Null
    Write-Status "docker-compose.windows.yml is valid"
} catch {
    Write-ErrorMsg "docker-compose.windows.yml validation failed!"
    exit 1
}

# Parse and show configuration
Write-Host ""
Write-Host "Current configuration from .env.windows:"
Get-Content ".env.windows" | Where-Object { $_ -match "^[^#]" -and $_ -match "=" } | ForEach-Object {
    $key, $value = $_ -split "=", 2
    if ($key -notmatch "PAT|TOKEN|SECRET") {
        Write-Host "  $key = $value"
    } elseif ($value -ne "your_github_personal_access_token_here") {
        Write-Host "  $key = ****" -ForegroundColor Gray
    }
}

# Confirmation
Write-Host ""
Write-Warning "This will deploy the GitHub Actions runner on this Windows VM"
$response = Read-Host "Are you ready to proceed? (y/N)"

if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Deployment cancelled"
    exit 0
}

# Check if runner is already running
$runningContainers = docker ps --format "{{.Names}}" | Select-String "github-runner-windows"
if ($runningContainers) {
    Write-Warning "Runner appears to be already running"
    $response = Read-Host "Do you want to restart it? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "Stopping existing runner..."
        docker-compose -f docker-compose.windows.yml down
        Write-Status "Existing runner stopped"
    } else {
        Write-Host "Deployment cancelled"
        exit 0
    }
}

# Deploy the runner
Write-Host ""
Write-Host "Starting GitHub Actions runner..."
try {
    docker-compose -f docker-compose.windows.yml --env-file .env.windows up -d

    Write-Status "Runner deployed successfully!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Check logs: docker-compose -f docker-compose.windows.yml logs -f"
    Write-Host "2. Verify in GitHub: https://github.com/organizations/jgowdy/settings/actions/runners"
    Write-Host "3. Monitor resources: docker stats github-runner-windows"
    Write-Host ""

    # Wait a few seconds and show initial logs
    Write-Host "Showing initial logs (Ctrl+C to exit)..."
    Start-Sleep -Seconds 3
    docker-compose -f docker-compose.windows.yml logs --tail=50 -f
} catch {
    Write-ErrorMsg "Deployment failed!"
    Write-Host $_.Exception.Message
    exit 1
}
