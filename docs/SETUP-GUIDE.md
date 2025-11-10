# GitHub Actions Runners - Complete Setup Guide

This guide will walk you through setting up GitHub Actions self-hosted runners on your infrastructure.

## Overview

**Organization**: jgowdy
**Primary Host**: bx.ee (Linux - production, requires careful deployment)
**Additional Hosts**: Windows VM (hosted on bx.ee), future hosts TBD

## Quick Reference

| Host Type | Installation Method | Files Needed | Documentation |
|-----------|-------------------|--------------|---------------|
| **Linux (bx.ee)** | Docker Compose | `docker-compose.yml`<br>`.env` | [README.md](README.md) |
| **Windows VM** | Native + Ephemeral | `install-windows-runner.ps1` | [README-WINDOWS-NATIVE.md](README-WINDOWS-NATIVE.md) |

## Prerequisites

### GitHub Organization Setup

1. **Create Personal Access Token (PAT)**
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Required scopes:
     - ✅ `admin:org` (to register organization runners)
     - ✅ `repo` (if needed for private repos)
   - Click "Generate token"
   - **Save the token securely** (you won't see it again)

2. **Verify Organization Access**
   - Ensure you have admin access to the `jgowdy` organization
   - Check: https://github.com/organizations/jgowdy/settings/actions/runners

## Installation Steps

### Part 1: Linux Runner on bx.ee (Docker)

**Why Docker**: Provides isolation, easy management, and consistency across different Linux hosts.

**⚠️ IMPORTANT**: bx.ee runs production services. Follow carefully!

#### Step 1: Prepare Configuration

```bash
# SSH into bx.ee
ssh user@bx.ee

# Create project directory
mkdir -p ~/github-runners
cd ~/github-runners

# Download/copy these files from this repo:
# - docker-compose.yml
# - .env.example
# - deploy.sh
# - check-runner.sh
# - .gitignore
```

#### Step 2: Configure Environment

```bash
# Copy example to actual .env
cp .env.example .env

# Edit with your values
nano .env
```

**Critical settings to update in `.env`**:
- `GITHUB_PAT`: Your GitHub Personal Access Token
- `ORG_NAME`: jgowdy (already set)
- `RUNNER_NAME`: Unique name (e.g., bx-ee-runner-1)
- `LABELS`: bx-ee,docker,linux (or customize)

**Review resource limits**:
```bash
# Check available CPU cores
nproc

# Check available memory
free -h

# Edit resource limits if needed
nano .env
# Adjust: CPU_LIMIT, MEMORY_LIMIT, CPU_RESERVATION, MEMORY_RESERVATION
```

#### Step 3: Pre-Deployment Checks

```bash
# Validate Docker Compose configuration
docker-compose config

# Check disk space (need >10GB free)
df -h

# Check Docker is running
docker ps

# Verify no port conflicts
docker-compose ps
```

#### Step 4: Deploy Runner

```bash
# Option A: Using the deployment script (recommended)
chmod +x deploy.sh
./deploy.sh

# Option B: Manual deployment
docker-compose up -d
docker-compose logs -f
```

#### Step 5: Verify

```bash
# Check runner status
./check-runner.sh

# Or manually:
docker-compose ps
docker-compose logs --tail=50

# Check in GitHub
# Visit: https://github.com/organizations/jgowdy/settings/actions/runners
# Should see your runner as "Idle"
```

**Full documentation**: [README.md](README.md)

---

### Part 2: Windows Runner on Windows VM (Native)

**Why Native**: Best performance for Win32 builds (.NET, C++, Visual Studio projects). Ephemeral mode provides isolation.

#### Step 1: Prepare Windows VM

1. **Connect to Windows VM**
   - Use RDP or console access
   - Ensure you have Administrator rights

2. **Copy installation script**
   - Transfer `install-windows-runner.ps1` to the VM
   - Suggested location: `C:\GitHub\install-windows-runner.ps1`

#### Step 2: Verify Prerequisites

```powershell
# Check PowerShell version (need 5.0+)
$PSVersionTable.PSVersion

# Verify you have admin rights
# Right-click PowerShell → Run as Administrator
```

#### Step 3: Configure and Run

```powershell
# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Run the installation script
.\install-windows-runner.ps1
```

The script will:
1. Prompt for your GitHub PAT (the same one from Part 1)
2. Download the latest GitHub Actions runner
3. Configure it with ephemeral mode
4. Install as a Windows service
5. Start the service

#### Step 4: Verify

```powershell
# Check service status
Get-Service "actions.runner.*"

# View logs
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50

# Check in GitHub
# Visit: https://github.com/organizations/jgowdy/settings/actions/runners
# Should see your Windows runner as "Idle"
```

**Full documentation**: [README-WINDOWS-NATIVE.md](README-WINDOWS-NATIVE.md)

---

## Using Your Runners in Workflows

### Targeting Specific Runners

Use labels to target specific runners:

```yaml
name: Multi-Platform Build
on: [push]

jobs:
  # Linux build on bx.ee
  build-linux:
    runs-on: [self-hosted, linux, bx-ee]
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: |
          npm install
          npm run build

  # Windows build on Windows VM
  build-windows:
    runs-on: [self-hosted, windows, bx-ee]
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: |
          dotnet build
          dotnet test
```

### Available Labels

**Linux runner (bx.ee)**:
- `self-hosted`
- `linux`
- `bx-ee`
- `docker`
- (any custom labels you added)

**Windows runner**:
- `self-hosted`
- `windows`
- `bx-ee`
- `win32`
- `native`
- `build`
- (any custom labels you added)

## Monitoring and Maintenance

### Daily/Weekly Checks

```bash
# Linux (bx.ee)
ssh user@bx.ee
cd ~/github-runners
./check-runner.sh
docker stats github-runner-bx-ee

# Windows
# RDP to Windows VM
Get-Service "actions.runner.*"
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 20
```

### Common Issues

#### Runner Shows Offline

**Linux**:
```bash
docker-compose ps
docker-compose logs --tail=50
docker-compose restart
```

**Windows**:
```powershell
Get-Service "actions.runner.*"
Restart-Service "actions.runner.*"
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50
```

#### Jobs Failing

1. Check job logs in GitHub Actions UI
2. Check runner logs (see above)
3. Verify required tools are installed
4. Check disk space
5. Check resource limits

#### High Resource Usage

**Linux**:
```bash
docker stats
# Adjust limits in .env
nano .env
docker-compose up -d  # Apply new limits
```

**Windows**:
```powershell
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
# Check for runaway processes
```

## Security Best Practices

### ✅ Do's

- ✅ Use ephemeral mode (enabled by default)
- ✅ Keep runners updated
- ✅ Monitor runner logs regularly
- ✅ Use GitHub Secrets for sensitive data
- ✅ Apply resource limits
- ✅ Keep PAT secure (never commit to git)
- ✅ Use dedicated service accounts where possible
- ✅ Only run trusted workflows

### ❌ Don'ts

- ❌ Don't commit `.env` files (it's in `.gitignore`)
- ❌ Don't share your GitHub PAT
- ❌ Don't run untrusted workflows on production hosts
- ❌ Don't disable security features without understanding impact
- ❌ Don't over-allocate resources on production hosts

## Scaling to More Hosts

When you're ready to add more runners:

### For Additional Linux Hosts

1. Copy the Linux setup files to the new host
2. Update `.env`:
   - Change `RUNNER_NAME` to be unique
   - Add host-specific labels
   - Adjust resource limits for that host
3. Run `./deploy.sh`

### For Additional Windows Hosts

1. Copy `install-windows-runner.ps1` to the new host
2. Edit the script to change `$RUNNER_NAME` and `$LABELS`
3. Run the script as Administrator

### For macOS Hosts

macOS runners would use native installation (similar to Windows). Let me know when you're ready to add macOS hosts, and I'll create the setup scripts.

## Troubleshooting

### "Permission Denied" Errors

**Linux**:
```bash
# Make sure scripts are executable
chmod +x deploy.sh check-runner.sh

# Check Docker permissions
sudo usermod -aG docker $USER
# Log out and back in
```

**Windows**:
```powershell
# Run PowerShell as Administrator
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```

### "Registration Failed" Errors

Common causes:
1. **Invalid PAT**: Check token hasn't expired
2. **Wrong permissions**: PAT needs `admin:org` scope
3. **Wrong organization name**: Verify `ORG_NAME=jgowdy`
4. **Network issues**: Check connectivity to github.com

```bash
# Test GitHub connectivity
curl -I https://api.github.com
curl -I https://github.com

# Test with PAT
curl -H "Authorization: token YOUR_PAT" https://api.github.com/orgs/jgowdy
```

### Disk Space Issues

**Linux**:
```bash
# Check disk space
df -h

# Clean old Docker resources
docker system prune -a

# Check runner work directory
du -sh runner-work/
```

**Windows**:
```powershell
# Check disk space
Get-PSDrive C

# Clean runner work directory
Get-ChildItem C:\actions-runner\_work -Directory |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item -Recurse -Force
```

## Next Steps

1. ✅ Set up Linux runner on bx.ee
2. ✅ Set up Windows runner on Windows VM
3. ⏭️ Test with sample workflows
4. ⏭️ Set up monitoring/alerting (optional)
5. ⏭️ Add more hosts as needed (macOS, other Linux servers, etc.)

## Support and Documentation

- **This repository**: Contains all setup scripts and documentation
- **GitHub Actions docs**: https://docs.github.com/en/actions/hosting-your-own-runners
- **Docker docs**: https://docs.docker.com/
- **GitHub Actions runner releases**: https://github.com/actions/runner/releases

## File Index

| File | Purpose |
|------|---------|
| `SETUP-GUIDE.md` | This file - complete setup walkthrough |
| `README.md` | Detailed Linux/Docker setup |
| `README-WINDOWS-NATIVE.md` | Detailed Windows native setup |
| `docker-compose.yml` | Docker Compose config for Linux |
| `.env.example` | Example environment variables for Linux |
| `deploy.sh` | Linux deployment script |
| `check-runner.sh` | Linux health check script |
| `install-windows-runner.ps1` | Windows installation script |
| `.gitignore` | Prevents committing secrets |

---

**Questions or issues?** Check the detailed documentation in the README files, or review GitHub Actions runner documentation.
