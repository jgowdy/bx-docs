# GitHub Actions Runner - Native Windows Installation

For **native Win32 builds** (.NET, C++, Visual Studio projects), install the GitHub Actions runner directly on Windows rather than in Docker.

## Why Native Installation?

- **Direct access** to Windows SDK, Visual Studio, .NET Framework
- **Better performance** - no Docker overhead
- **Easier debugging** - native Windows environment
- **Full Windows features** - COM, registry, Windows services, etc.
- **Build tools integration** - MSBuild, Visual Studio, etc.

## Prerequisites

### Windows VM Requirements:
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.0 or higher
- **Administrator access** (required for service installation)
- Network access to GitHub
- Build tools installed (Visual Studio, .NET SDK, etc.)

### GitHub Requirements:
- GitHub Personal Access Token (PAT) with `admin:org` scope
- Organization admin access

## Quick Installation

### Option 1: Automated Script (Recommended)

1. **Download the installation script** to the Windows VM
   - Transfer `install-windows-runner.ps1` to the VM

2. **Edit configuration** in the script (optional):
   ```powershell
   # Open in editor
   notepad install-windows-runner.ps1

   # Edit these variables at the top:
   $ORG_NAME = "jgowdy"           # Your organization
   $RUNNER_NAME = "..."           # Runner name (default uses computer name)
   $LABELS = "bx-ee,windows,..."  # Labels for targeting workflows
   ```

3. **Run as Administrator**:
   ```powershell
   # Right-click PowerShell → Run as Administrator
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   .\install-windows-runner.ps1
   ```

4. **Enter your GitHub PAT** when prompted

The script will:
- Download the latest GitHub Actions runner
- Get a registration token from GitHub
- Configure the runner
- Install it as a Windows service
- Start the service

### Option 2: Manual Installation

1. **Create runner directory**:
   ```powershell
   New-Item -ItemType Directory -Path C:\actions-runner
   cd C:\actions-runner
   ```

2. **Download latest runner**:
   ```powershell
   # Check latest version at: https://github.com/actions/runner/releases
   $version = "2.311.0"  # Replace with latest version
   Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$version/actions-runner-win-x64-$version.zip" -OutFile "actions-runner.zip"
   Expand-Archive -Path actions-runner.zip -DestinationPath .
   Remove-Item actions-runner.zip
   ```

3. **Get registration token** from GitHub:
   - Go to: `https://github.com/organizations/jgowdy/settings/actions/runners/new`
   - Or use API with your PAT:
     ```powershell
     $headers = @{ "Authorization" = "token YOUR_PAT_HERE" }
     $response = Invoke-RestMethod -Uri "https://api.github.com/orgs/jgowdy/actions/runners/registration-token" -Method Post -Headers $headers
     $token = $response.token
     ```

4. **Configure runner**:
   ```powershell
   .\config.cmd --url https://github.com/jgowdy `
                --token YOUR_REGISTRATION_TOKEN `
                --name bx-ee-windows-runner `
                --labels bx-ee,windows,win32,native `
                --runnergroup default `
                --work _work `
                --unattended
   ```

5. **Install as Windows service**:
   ```powershell
   # Must run as Administrator
   .\svc.cmd install
   .\svc.cmd start
   ```

## Verification

1. **Check service is running**:
   ```powershell
   Get-Service "actions.runner.*"
   ```

2. **View logs**:
   ```powershell
   Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50 -Wait
   ```

3. **Check in GitHub**:
   - Visit: `https://github.com/organizations/jgowdy/settings/actions/runners`
   - Your runner should appear as "Idle"

## Using the Runner in Workflows

Target your Windows runner with labels:

```yaml
name: Windows Build
on: [push]

jobs:
  build-windows:
    runs-on: [self-hosted, windows, bx-ee]

    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '7.0'

      - name: Build
        run: dotnet build

      - name: Test
        run: dotnet test
```

For Visual Studio builds:

```yaml
jobs:
  build-cpp:
    runs-on: [self-hosted, windows, win32]

    steps:
      - uses: actions/checkout@v3

      - name: Setup MSBuild
        uses: microsoft/setup-msbuild@v1

      - name: Build
        run: msbuild MyProject.sln /p:Configuration=Release /p:Platform=x64
```

## Managing the Runner

### Check Status
```powershell
# Service status
Get-Service "actions.runner.*"

# Process status
Get-Process | Where-Object { $_.ProcessName -like "*Runner*" }
```

### View Logs
```powershell
# Live logs
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50 -Wait

# Worker logs (job execution)
Get-Content C:\actions-runner\_diag\Worker_*.log -Tail 50
```

### Stop/Start Service
```powershell
# Stop
Stop-Service "actions.runner.*"

# Start
Start-Service "actions.runner.*"

# Restart
Restart-Service "actions.runner.*"
```

### Update Runner

```powershell
cd C:\actions-runner

# Stop service
.\svc.cmd stop

# Uninstall service (temporarily)
.\svc.cmd uninstall

# Remove runner from GitHub (optional)
.\config.cmd remove --token YOUR_TOKEN

# Download new version (see manual installation steps)
# Configure again
# Reinstall service
.\svc.cmd install
.\svc.cmd start
```

### Uninstall Runner

```powershell
cd C:\actions-runner

# Stop service
.\svc.cmd stop

# Uninstall service
.\svc.cmd uninstall

# Remove runner from GitHub
# Get a removal token from GitHub or use PAT
.\config.cmd remove --token YOUR_TOKEN

# Delete directory (optional)
cd \
Remove-Item -Recurse -Force C:\actions-runner
```

## Configuration Options

### Runner Labels

Labels help target specific runners in workflows. Common labels for Windows:

- `windows` - Windows OS
- `win32` - Native Windows (not WSL/container)
- `bx-ee` - Your specific host
- `build` - Build capabilities
- `x64` or `x86` - Architecture
- `vs2022` - Visual Studio version
- `dotnet7` - .NET version

Example: `windows,win32,bx-ee,build,x64,vs2022`

### Work Directory

Default: `C:\actions-runner\_work`

This is where jobs check out code and run. Ensure sufficient disk space.

### Service Account

By default, runs as `NT AUTHORITY\NETWORK SERVICE`. To change:

```powershell
# In config.cmd, add:
--windowslogonaccount "DOMAIN\username" --windowslogonpassword "password"
```

## Build Environment Setup

Install required build tools on the Windows VM:

### For .NET Development
```powershell
# .NET SDK
winget install Microsoft.DotNet.SDK.7

# Or download from: https://dotnet.microsoft.com/download
```

### For C++ Development
```powershell
# Visual Studio Build Tools
# Download from: https://visualstudio.microsoft.com/downloads/

# Or full Visual Studio
winget install Microsoft.VisualStudio.2022.Community
```

### For Node.js Development
```powershell
winget install OpenJS.NodeJS
```

### Common Tools
```powershell
# Git
winget install Git.Git

# Python (if needed)
winget install Python.Python.3.11
```

## Performance Tuning

### Disk Space Management

```powershell
# Check work directory size
Get-ChildItem C:\actions-runner\_work -Recurse |
    Measure-Object -Property Length -Sum |
    Select-Object @{Name="SizeGB";Expression={[math]::Round($_.Sum/1GB,2)}}

# Clean old job directories periodically
Get-ChildItem C:\actions-runner\_work -Directory |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item -Recurse -Force
```

### Resource Monitoring

```powershell
# Monitor runner CPU/Memory
Get-Process | Where-Object { $_.ProcessName -like "*Runner*" } |
    Format-Table ProcessName, CPU, WorkingSet -AutoSize

# Continuous monitoring
while ($true) {
    Clear-Host
    Get-Process | Where-Object { $_.ProcessName -like "*Runner*" } |
        Format-Table ProcessName, CPU, @{Name="MemoryMB";Expression={$_.WorkingSet/1MB}} -AutoSize
    Start-Sleep -Seconds 2
}
```

## Security Considerations

### Service Account Permissions
- Use least-privilege account
- Only grant necessary permissions
- Consider using a dedicated service account

### Network Security
- Requires outbound HTTPS to:
  - github.com
  - api.github.com
  - *.actions.githubusercontent.com
  - pipelines.actions.githubusercontent.com
- No inbound connections required

### Code Execution
- Workflows run with service account permissions
- Can execute arbitrary code
- **Only run trusted workflows**
- Consider using separate VMs for untrusted code

### Secrets Management
- Never log secrets
- Use GitHub Secrets for sensitive data
- Clear build artifacts that may contain secrets

## Troubleshooting

### Service Won't Start

1. Check Event Viewer:
   ```powershell
   Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 20
   ```

2. Check service account has proper permissions
3. Verify network connectivity to GitHub
4. Check runner logs in `_diag` folder

### Runner Shows Offline in GitHub

1. Check service is running
2. Check network connectivity:
   ```powershell
   Test-NetConnection github.com -Port 443
   Test-NetConnection api.github.com -Port 443
   ```
3. Check firewall/proxy settings
4. Review runner logs for errors

### Jobs Failing

1. Check job logs in GitHub Actions UI
2. Check runner logs: `C:\actions-runner\_diag\Worker_*.log`
3. Verify required build tools are installed
4. Check disk space
5. Verify service account permissions

### High Resource Usage

1. Monitor with Task Manager or:
   ```powershell
   Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
   ```

2. Check for zombie processes
3. Review job configuration (parallel jobs, resource-intensive tasks)
4. Consider adding more runners to distribute load

## Monitoring and Maintenance

### Health Checks

Create a scheduled task to monitor runner health:

```powershell
# Check-RunnerHealth.ps1
$service = Get-Service "actions.runner.*"
if ($service.Status -ne "Running") {
    # Send alert (email, webhook, etc.)
    Write-Error "Runner service is not running!"
    # Attempt restart
    Start-Service $service
}
```

### Log Rotation

GitHub Actions runner has built-in log rotation, but monitor:

```powershell
# Check log directory size
Get-ChildItem C:\actions-runner\_diag -Recurse |
    Measure-Object -Property Length -Sum
```

### Regular Maintenance

- **Weekly**: Check service status and logs
- **Monthly**: Review disk space usage
- **Monthly**: Check for runner updates
- **Quarterly**: Review and update build tools
- **Quarterly**: Review security settings

## Production Deployment Checklist

- [ ] Windows VM has sufficient resources (CPU, RAM, disk)
- [ ] Required build tools installed (Visual Studio, .NET, etc.)
- [ ] GitHub PAT created with correct permissions
- [ ] Firewall allows outbound HTTPS to GitHub
- [ ] Service account configured with appropriate permissions
- [ ] Runner installed and configured
- [ ] Service installed and running
- [ ] Runner appears in GitHub as "Idle"
- [ ] Test workflow executed successfully
- [ ] Monitoring/alerting configured
- [ ] Documentation updated with VM-specific details
- [ ] Backup/recovery procedure documented

## Support Resources

- GitHub Actions docs: https://docs.github.com/en/actions/hosting-your-own-runners
- Runner releases: https://github.com/actions/runner/releases
- Windows service management: https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create
