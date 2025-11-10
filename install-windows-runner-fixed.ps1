# GitHub Actions Runner - Native Windows Installation
#Requires -Version 5.0
#Requires -RunAsAdministrator

$ORG_NAME = "TeamEightStar"
$RUNNER_NAME = "$env:COMPUTERNAME-runner"
$LABELS = "bx-ee,windows,win32,native,build"
$RUNNER_GROUP = "default"
$GITHUB_PAT = "ghp_YOUR_TOKEN_HERE"
$RUNNER_DIR = "C:\actions-runner"

Write-Host "Installing GitHub Actions Runner for $ORG_NAME" -ForegroundColor Cyan

# Create directory
if (-not (Test-Path $RUNNER_DIR)) {
    New-Item -ItemType Directory -Path $RUNNER_DIR | Out-Null
}

Push-Location $RUNNER_DIR

# Download runner
$latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner/releases/latest"
$version = $latestRelease.tag_name.TrimStart('v')
$runnerUrl = "https://github.com/actions/runner/releases/download/v${version}/actions-runner-win-x64-${version}.zip"
$runnerZip = "runner.zip"

Write-Host "Downloading runner version $version..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerZip
Expand-Archive -Path $runnerZip -DestinationPath $RUNNER_DIR -Force
Remove-Item $runnerZip

# Get registration token
$headers = @{
    "Authorization" = "token $GITHUB_PAT"
    "Accept" = "application/vnd.github.v3+json"
}
$tokenUrl = "https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token"
$tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers
$RUNNER_TOKEN = $tokenResponse.token

# Configure runner
Write-Host "Configuring runner..." -ForegroundColor Yellow
& .\config.cmd --url "https://github.com/$ORG_NAME" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --labels "$LABELS" --runnergroup "$RUNNER_GROUP" --work "_work" --ephemeral --unattended

# Install and start service
Write-Host "Installing as Windows service..." -ForegroundColor Yellow
& .\svc.cmd install
& .\svc.cmd start

Pop-Location

Write-Host "Installation complete!" -ForegroundColor Green
Get-Service "actions.runner.*"
