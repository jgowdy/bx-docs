#Requires -RunAsAdministrator

$ORG_NAME = "TeamEightStar"
$RUNNER_NAME = "$env:COMPUTERNAME-runner"
$LABELS = "bx-ee,windows,win32,native,build"
$GITHUB_PAT = "ghp_YOUR_TOKEN_HERE"

Set-Location C:\actions-runner

# Get removal token
Write-Host "Getting removal token..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "token $GITHUB_PAT"
    "Accept" = "application/vnd.github.v3+json"
}
$tokenUrl = "https://api.github.com/orgs/$ORG_NAME/actions/runners/remove-token"
$removeToken = (Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers).token

# Remove existing config
Write-Host "Removing existing configuration..." -ForegroundColor Yellow
& .\config.cmd remove --token $removeToken

# Get new registration token
Write-Host "Getting registration token..." -ForegroundColor Yellow
$tokenUrl = "https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token"
$regToken = (Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers).token

# Configure WITH service - use runasservice flag
Write-Host "Configuring runner as Windows service..." -ForegroundColor Yellow
& .\config.cmd --url "https://github.com/$ORG_NAME" --token $regToken --name $RUNNER_NAME --labels $LABELS --work "_work" --ephemeral --runasservice --unattended

if ($LASTEXITCODE -eq 0) {
    Write-Host "Runner configured as service successfully!" -ForegroundColor Green

    # Start the service
    $serviceName = "actions.runner.TeamEightStar.$RUNNER_NAME"
    Start-Service $serviceName

    Write-Host "Service started!" -ForegroundColor Green
    Get-Service $serviceName | Format-List
} else {
    Write-Host "Configuration failed!" -ForegroundColor Red
}
