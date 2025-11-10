# GitHub Actions Runner - Native Windows Installation
# This script installs the GitHub Actions runner as a Windows service
# For native Win32 builds (.NET, C++, etc.)

#Requires -Version 5.0
#Requires -RunAsAdministrator

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "GitHub Actions Runner - Native Windows Install" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration - EDIT THESE VALUES
$ORG_NAME = "TeamEightStar"
$RUNNER_NAME = "$env:COMPUTERNAME-runner"  # Uses computer name
$LABELS = "bx-ee,windows,win32,native,build"
$RUNNER_GROUP = "default"
$GITHUB_PAT_PRESET = "ghp_YOUR_TOKEN_HERE"  # Replace with your GitHub PAT

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Organization: $ORG_NAME"
Write-Host "  Runner Name: $RUNNER_NAME"
Write-Host "  Labels: $LABELS"
Write-Host ""

# Use preset PAT or prompt
if ([string]::IsNullOrWhiteSpace($GITHUB_PAT_PRESET)) {
    $GITHUB_PAT = Read-Host "Enter your GitHub Personal Access Token (PAT)" -AsSecureString
    $GITHUB_PAT_Plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($GITHUB_PAT))
} else {
    $GITHUB_PAT_Plain = $GITHUB_PAT_PRESET
    Write-Host "Using preset GitHub PAT" -ForegroundColor Cyan
}

if ([string]::IsNullOrWhiteSpace($GITHUB_PAT_Plain)) {
    Write-Host "[✗] GitHub PAT is required!" -ForegroundColor Red
    exit 1
}

Write-Host "[✓] GitHub PAT provided" -ForegroundColor Green

# Create runner directory
$RUNNER_DIR = "C:\actions-runner"
if (-not (Test-Path $RUNNER_DIR)) {
    Write-Host "Creating runner directory: $RUNNER_DIR"
    New-Item -ItemType Directory -Path $RUNNER_DIR | Out-Null
    Write-Host "[✓] Runner directory created" -ForegroundColor Green
} else {
    Write-Host "[!] Runner directory already exists" -ForegroundColor Yellow
    $response = Read-Host "Continue and potentially overwrite? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit 0
    }
}

# Download latest runner
Write-Host ""
Write-Host "Downloading latest GitHub Actions runner..."
Push-Location $RUNNER_DIR

try {
    # Get latest runner version
    $latestReleaseUrl = "https://api.github.com/repos/actions/runner/releases/latest"
    $latestRelease = Invoke-RestMethod -Uri $latestReleaseUrl
    $version = $latestRelease.tag_name.TrimStart('v')

    Write-Host "Latest version: $version" -ForegroundColor Cyan

    # Download runner
    $runnerUrl = "https://github.com/actions/runner/releases/download/v${version}/actions-runner-win-x64-${version}.zip"
    $runnerZip = "actions-runner-win-x64-${version}.zip"

    Write-Host "Downloading from: $runnerUrl"

    # Use .NET WebClient for download with progress
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($runnerUrl, "$RUNNER_DIR\$runnerZip")

    Write-Host "[✓] Download complete" -ForegroundColor Green

    # Extract runner
    Write-Host "Extracting runner..."
    Expand-Archive -Path $runnerZip -DestinationPath $RUNNER_DIR -Force
    Remove-Item $runnerZip

    Write-Host "[✓] Runner extracted" -ForegroundColor Green

} catch {
    Write-Host "[✗] Failed to download/extract runner" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Pop-Location
    exit 1
}

# Get registration token from GitHub
Write-Host ""
Write-Host "Getting registration token from GitHub..."

try {
    $headers = @{
        "Authorization" = "token $GITHUB_PAT_Plain"
        "Accept" = "application/vnd.github.v3+json"
    }

    $tokenUrl = "https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token"
    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers
    $RUNNER_TOKEN = $tokenResponse.token

    Write-Host "[✓] Registration token obtained" -ForegroundColor Green

} catch {
    Write-Host "[✗] Failed to get registration token" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Common causes:" -ForegroundColor Yellow
    Write-Host "  - Invalid PAT"
    Write-Host "  - PAT missing 'admin:org' scope"
    Write-Host "  - Incorrect organization name"
    Write-Host "  - Network connectivity issues"
    Pop-Location
    exit 1
}

# Configure runner
Write-Host ""
Write-Host "Configuring runner..."

try {
    $configArgs = @(
        "--url", "https://github.com/$ORG_NAME",
        "--token", "$RUNNER_TOKEN",
        "--name", "$RUNNER_NAME",
        "--labels", "$LABELS",
        "--runnergroup", "$RUNNER_GROUP",
        "--work", "_work",
        "--ephemeral",
        "--unattended"
    )

    & .\config.cmd @configArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] Runner configured successfully" -ForegroundColor Green
    } else {
        Write-Host "[✗] Runner configuration failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }

} catch {
    Write-Host "[✗] Failed to configure runner" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Pop-Location
    exit 1
}

# Install and start as Windows service
Write-Host ""
Write-Host "Installing runner as Windows service..."

try {
    # Install service
    & .\svc.cmd install

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] Service installed" -ForegroundColor Green
    } else {
        Write-Host "[✗] Service installation failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    # Start service
    Write-Host "Starting service..."
    & .\svc.cmd start

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] Service started successfully" -ForegroundColor Green
    } else {
        Write-Host "[✗] Service failed to start" -ForegroundColor Red
        Pop-Location
        exit 1
    }

} catch {
    Write-Host "[✗] Failed to install/start service" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Pop-Location
    exit 1
}

Pop-Location

# Final verification
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Verify runner in GitHub:"
Write-Host "   https://github.com/organizations/$ORG_NAME/settings/actions/runners"
Write-Host ""
Write-Host "2. Check service status:"
Write-Host "   Get-Service 'actions.runner.*'"
Write-Host ""
Write-Host "3. View runner logs:"
Write-Host "   Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50 -Wait"
Write-Host ""
Write-Host "4. Test with a workflow:"
Write-Host "   runs-on: [self-hosted, windows, bx-ee]"
Write-Host ""

# Show service status
Write-Host "Current service status:" -ForegroundColor Cyan
Get-Service "actions.runner.*" | Format-Table -AutoSize
