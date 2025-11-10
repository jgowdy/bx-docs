#Requires -RunAsAdministrator

Set-Location C:\actions-runner

# Check if svc.cmd exists
if (-not (Test-Path ".\svc.cmd")) {
    Write-Host "ERROR: svc.cmd not found. Runner is not configured." -ForegroundColor Red
    Write-Host "Run config.cmd first, then try again." -ForegroundColor Yellow
    exit 1
}

# Install service
Write-Host "Installing Windows service..." -ForegroundColor Yellow
& .\svc.cmd install

if ($LASTEXITCODE -ne 0) {
    Write-Host "Service installation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Service installed successfully" -ForegroundColor Green

# Set to automatic startup
$serviceName = (Get-Service "actions.runner.*").Name
Set-Service $serviceName -StartupType Automatic
Write-Host "Set service to automatic startup" -ForegroundColor Green

# Start service
Start-Service $serviceName
Write-Host "Service started" -ForegroundColor Green

# Show status
Get-Service $serviceName | Format-List Name, Status, StartType
