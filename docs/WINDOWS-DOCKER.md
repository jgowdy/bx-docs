# GitHub Actions Runner - Windows VM Setup

This guide covers setting up a GitHub Actions self-hosted runner on the Windows VM hosted on bx.ee.

## Prerequisites

### Windows VM Requirements:
- Windows 10/11 or Windows Server 2016+
- Docker Desktop for Windows installed and running
- PowerShell 5.0 or higher
- Administrator access
- Network access to GitHub (github.com and api.github.com)
- Sufficient resources (recommended: 4+ CPU cores, 8GB+ RAM)

### GitHub Requirements:
- Same GitHub Personal Access Token (PAT) used for Linux runners
- Organization admin access

## Quick Start

### 1. Copy Files to Windows VM

Transfer these files to the Windows VM:
- `docker-compose.windows.yml`
- `.env.windows.example`
- `deploy-windows.ps1`

You can use:
- RDP file transfer
- Network share
- SCP/SFTP if SSH is enabled
- Git clone this repository

### 2. Configure Environment

```powershell
# Copy the example environment file
Copy-Item .env.windows.example .env.windows

# Edit with your favorite editor
notepad .env.windows
```

**Required changes:**
- Set `GITHUB_PAT` to your GitHub Personal Access Token
- Verify `RUNNER_NAME` is unique (default: bx-ee-windows-runner-1)
- Adjust `LABELS` if needed (default: bx-ee,windows,docker,build)

### 3. Deploy Runner

```powershell
# Run the deployment script
.\deploy-windows.ps1
```

The script will:
- Verify prerequisites
- Validate configuration
- Check available resources
- Deploy the runner
- Show initial logs

## Manual Deployment (Alternative)

If you prefer not to use the script:

```powershell
# Start Docker Desktop (if not running)
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for Docker to be ready
Start-Sleep -Seconds 30

# Deploy the runner
docker-compose -f docker-compose.windows.yml --env-file .env.windows up -d

# View logs
docker-compose -f docker-compose.windows.yml logs -f
```

## Managing the Runner

### View Logs
```powershell
docker-compose -f docker-compose.windows.yml logs -f
```

### Check Status
```powershell
docker ps | Select-String "github-runner-windows"
```

### Restart Runner
```powershell
docker-compose -f docker-compose.windows.yml restart
```

### Stop Runner
```powershell
docker-compose -f docker-compose.windows.yml down
```

### Update Runner Image
```powershell
# Pull latest image
docker-compose -f docker-compose.windows.yml pull

# Recreate container
docker-compose -f docker-compose.windows.yml up -d
```

### Monitor Resources
```powershell
# View resource usage
docker stats github-runner-windows

# View system resources
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
```

## Configuration Details

### Resource Limits

Default limits in `.env.windows`:
- CPU: 2.0 cores max
- Memory: 4GB max

**To adjust for your VM:**

```powershell
# Check available CPU cores
(Get-WmiObject Win32_Processor).NumberOfLogicalProcessors

# Check available memory
(Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB

# Edit .env.windows to adjust limits
notepad .env.windows
```

### Labels

The `LABELS` setting determines which workflows can use this runner. Default: `bx-ee,windows,docker,build`

**Example workflow targeting this runner:**
```yaml
name: Windows Build
on: [push]
jobs:
  build:
    runs-on: [self-hosted, windows, bx-ee]
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: |
          # Your Windows build commands here
          dotnet build
```

### Ephemeral Mode

`EPHEMERAL=true` (recommended):
- Runner is removed from GitHub after each job
- Automatically re-registers for the next job
- Provides clean state and better security
- Prevents state pollution between jobs

## Troubleshooting

### Docker Desktop Not Starting

1. Check if Hyper-V is enabled:
   ```powershell
   Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
   ```

2. Check if WSL 2 is installed (for WSL 2 backend):
   ```powershell
   wsl --status
   ```

3. Restart Docker Desktop:
   ```powershell
   Stop-Process -Name "Docker Desktop" -Force
   Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
   ```

### Runner Not Appearing in GitHub

1. Check logs for authentication errors:
   ```powershell
   docker-compose -f docker-compose.windows.yml logs | Select-String "error"
   ```

2. Verify PAT has correct permissions (admin:org)

3. Check network connectivity:
   ```powershell
   Test-NetConnection github.com -Port 443
   Test-NetConnection api.github.com -Port 443
   ```

### Container Keeps Restarting

1. Check container logs:
   ```powershell
   docker logs github-runner-windows
   ```

2. Check Docker events:
   ```powershell
   docker events --filter container=github-runner-windows
   ```

3. Verify resource limits aren't too restrictive

### Disk Space Issues

1. Check available space:
   ```powershell
   Get-PSDrive C | Select-Object Used,Free
   ```

2. Clean Docker resources:
   ```powershell
   docker system prune -a
   ```

3. Check Docker disk image location and size:
   ```powershell
   # In Docker Desktop settings: Settings > Resources > Advanced
   ```

## Windows-Specific Considerations

### Line Endings
- Windows uses CRLF (`\r\n`) line endings
- Ensure your workflows handle this correctly
- Use `.gitattributes` to manage line endings

### File Paths
- Windows uses backslashes (`\`) in paths
- Docker prefers forward slashes (`/`)
- PowerShell can handle both

### Case Sensitivity
- Windows file system is case-insensitive
- Linux is case-sensitive
- Test workflows that will run on both platforms carefully

### Docker-in-Docker
- The runner has access to Docker Desktop
- Can build Windows and Linux containers
- Linux containers run in WSL 2 (if using WSL 2 backend)

## Security Considerations

### Firewall
- Outbound HTTPS (443) must be allowed to:
  - github.com
  - api.github.com
  - *.actions.githubusercontent.com

### Antivirus
- Exclude Docker directories from real-time scanning:
  - `C:\ProgramData\Docker`
  - `C:\Users\<user>\AppData\Local\Docker`
- Or exclude the runner container specifically

### Updates
- Keep Docker Desktop updated
- Keep Windows updated
- Monitor security advisories for GitHub Actions

### Docker Socket Access
- The runner has full Docker access
- Workflows can build/run containers
- **Security Note**: This gives workflows significant VM access
- Only run trusted workflows

## Performance Optimization

### Docker Desktop Settings

1. Adjust WSL 2 memory limit (if using WSL 2):
   Create/edit `C:\Users\<user>\.wslconfig`:
   ```ini
   [wsl2]
   memory=4GB
   processors=2
   ```

2. Adjust Docker resources:
   - Docker Desktop → Settings → Resources
   - Allocate appropriate CPU/Memory/Disk

### Windows VM Optimization

1. Disable unnecessary startup programs
2. Disable Windows Search indexing on runner directories
3. Consider disabling Windows Defender real-time scanning for runner directories (with caution)

## Verification

After deployment:

1. **Check container is running:**
   ```powershell
   docker ps | Select-String "github-runner-windows"
   ```

2. **Check logs:**
   ```powershell
   docker-compose -f docker-compose.windows.yml logs
   ```

3. **Verify in GitHub:**
   - Visit: https://github.com/organizations/jgowdy/settings/actions/runners
   - You should see your Windows runner listed as "Idle"
   - Verify labels match your configuration

4. **Test with a workflow:**
   ```yaml
   name: Test Windows Runner
   on: workflow_dispatch
   jobs:
     test:
       runs-on: [self-hosted, windows, bx-ee]
       steps:
         - run: echo "Hello from Windows runner!"
         - run: systeminfo
   ```

## Backup and Recovery

### Backup Configuration
```powershell
# Backup .env.windows (contains PAT - store securely!)
Copy-Item .env.windows .env.windows.backup

# Export Docker volumes (if needed)
docker run --rm -v github-runner-windows_runner-work:/data -v ${PWD}:/backup alpine tar czf /backup/runner-backup.tar.gz /data
```

### Restore Configuration
```powershell
# Restore .env.windows
Copy-Item .env.windows.backup .env.windows

# Redeploy
.\deploy-windows.ps1
```

## Maintenance Schedule

- **Weekly**: Check runner status and logs
- **Monthly**: Check for Docker Desktop updates
- **Monthly**: Review disk space usage
- **Quarterly**: Review security settings and access

## Support Resources

- Docker Desktop docs: https://docs.docker.com/desktop/windows/
- GitHub Actions docs: https://docs.github.com/en/actions/hosting-your-own-runners
- PowerShell docs: https://docs.microsoft.com/en-us/powershell/

## Next Steps

After the Windows runner is working:
1. Test with actual build workflows
2. Configure monitoring/alerting
3. Document any Windows-specific build requirements
4. Set up other hosts (macOS, Linux) as needed
