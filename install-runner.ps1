#Requires -Version 5.0
#Requires -RunAsAdministrator

$ORG_NAME = "TeamEightStar"
$RUNNER_NAME = "$env:COMPUTERNAME-runner"
$LABELS = "bx-ee,windows,win32,native,build"
$RUNNER_GROUP = "default"
$GITHUB_PAT = "ghp_YOUR_TOKEN_HERE"
$RUNNER_DIR = "C:\actions-runner"

Write-Host "Installing GitHub Actions Runner" -ForegroundColor Cyan

# Create directory
if (-not (Test-Path $RUNNER_DIR)) {
    New-Item -ItemType Directory -Path $RUNNER_DIR | Out-Null
}

Set-Location $RUNNER_DIR

# Download if needed
if (-not (Test-Path ".\config.cmd")) {
    Write-Host "Downloading runner..." -ForegroundColor Yellow
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner/releases/latest"
    $version = $latestRelease.tag_name.TrimStart('v')
    $runnerUrl = "https://github.com/actions/runner/releases/download/v${version}/actions-runner-win-x64-${version}.zip"

    Invoke-WebRequest -Uri $runnerUrl -OutFile "runner.zip"
    Expand-Archive -Path "runner.zip" -DestinationPath . -Force
    Remove-Item "runner.zip"
    Write-Host "Downloaded version $version" -ForegroundColor Green
}

# Get registration token
Write-Host "Getting registration token..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "token $GITHUB_PAT"
    "Accept" = "application/vnd.github.v3+json"
}
$tokenUrl = "https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token"
$tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers
$RUNNER_TOKEN = $tokenResponse.token

# Configure runner
Write-Host "Configuring runner..." -ForegroundColor Yellow
$configArgs = "--url", "https://github.com/$ORG_NAME", "--token", $RUNNER_TOKEN, "--name", $RUNNER_NAME, "--labels", $LABELS, "--runnergroup", $RUNNER_GROUP, "--work", "_work", "--ephemeral", "--unattended"
& .\config.cmd @configArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "Configuration failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Runner configured successfully" -ForegroundColor Green

# Install and start service
Write-Host "Installing Windows service..." -ForegroundColor Yellow
& .\svc.cmd install

if ($LASTEXITCODE -ne 0) {
    Write-Host "Service installation failed!" -ForegroundColor Red
    exit 1
}

& .\svc.cmd start

if ($LASTEXITCODE -ne 0) {
    Write-Host "Service start failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "Runner is now running as a Windows service" -ForegroundColor Green

Get-Service "actions.runner.*"
