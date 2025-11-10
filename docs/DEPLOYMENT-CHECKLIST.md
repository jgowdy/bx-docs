# GitHub Actions Runners - Deployment Checklist

Use this checklist to ensure you don't miss any steps during deployment.

## Pre-Deployment (One Time Setup)

### GitHub Organization Setup
- [ ] Created GitHub Personal Access Token (PAT)
- [ ] PAT has `admin:org` scope
- [ ] PAT has `repo` scope (if needed)
- [ ] PAT is saved securely (password manager, secure note, etc.)
- [ ] Verified admin access to `jgowdy` organization
- [ ] Tested PAT works:
  ```bash
  curl -H "Authorization: token YOUR_PAT" https://api.github.com/orgs/jgowdy
  ```

## Linux Runner on bx.ee

### Pre-Deployment Checks
- [ ] SSH access to bx.ee verified
- [ ] Docker is installed and running
- [ ] Docker Compose is installed
- [ ] Current user can run Docker (in docker group)
- [ ] Sufficient disk space (>10GB free)
- [ ] Reviewed resource usage on bx.ee
- [ ] Determined safe resource limits

### Configuration
- [ ] Created project directory (e.g., `~/github-runners`)
- [ ] Copied setup files to bx.ee:
  - [ ] `docker-compose.yml`
  - [ ] `.env.example`
  - [ ] `deploy.sh`
  - [ ] `check-runner.sh`
  - [ ] `.gitignore`
- [ ] Created `.env` from `.env.example`
- [ ] Set `GITHUB_PAT` in `.env`
- [ ] Verified `ORG_NAME=jgowdy` in `.env`
- [ ] Set unique `RUNNER_NAME` in `.env`
- [ ] Configured appropriate `LABELS` in `.env`
- [ ] Set resource limits in `.env`:
  - [ ] `CPU_LIMIT` (based on `nproc` output)
  - [ ] `MEMORY_LIMIT` (based on `free -h` output)
- [ ] Validated config: `docker-compose config`

### Deployment
- [ ] Made deployment script executable: `chmod +x deploy.sh`
- [ ] Ran deployment: `./deploy.sh`
- [ ] Reviewed output for errors
- [ ] Container is running: `docker-compose ps`
- [ ] Logs look healthy: `docker-compose logs`
- [ ] Runner appears in GitHub as "Idle"
- [ ] Resource usage is acceptable: `docker stats`

### Testing
- [ ] Created test workflow targeting this runner
- [ ] Test workflow runs successfully
- [ ] Job logs show expected output
- [ ] No errors in runner logs

### Documentation
- [ ] Documented bx.ee-specific notes (if any)
- [ ] Saved `.env` backup securely (encrypted, not in git)
- [ ] Noted runner name and labels for reference

## Windows Runner on Windows VM

### Pre-Deployment Checks
- [ ] RDP/Console access to Windows VM verified
- [ ] Administrator access verified
- [ ] PowerShell version checked (5.0+)
- [ ] Network connectivity to GitHub verified
- [ ] Sufficient disk space (>20GB free on C:)
- [ ] Build tools installed (Visual Studio, .NET SDK, etc.)

### Configuration
- [ ] Copied `install-windows-runner.ps1` to Windows VM
- [ ] Reviewed script configuration:
  - [ ] `$ORG_NAME = "jgowdy"`
  - [ ] `$RUNNER_NAME` (should be unique)
  - [ ] `$LABELS` (should include windows, bx-ee, etc.)
- [ ] Modified configuration if needed

### Deployment
- [ ] Opened PowerShell as Administrator
- [ ] Set execution policy (if needed)
- [ ] Ran installation script: `.\install-windows-runner.ps1`
- [ ] Entered GitHub PAT when prompted
- [ ] Installation completed without errors
- [ ] Service is installed: `Get-Service "actions.runner.*"`
- [ ] Service is running
- [ ] Runner appears in GitHub as "Idle"

### Testing
- [ ] Created test workflow targeting Windows runner
- [ ] Test workflow runs successfully
- [ ] Windows-specific builds work (e.g., .NET, C++)
- [ ] No errors in runner logs

### Documentation
- [ ] Documented Windows VM-specific notes
- [ ] Noted installed build tools and versions
- [ ] Noted runner name and labels for reference

## Post-Deployment (Both Runners)

### Verification
- [ ] Both runners show as "Idle" in GitHub:
  https://github.com/organizations/jgowdy/settings/actions/runners
- [ ] Linux runner has correct labels
- [ ] Windows runner has correct labels
- [ ] Can differentiate runners by labels

### Testing Multi-Platform Workflow
- [ ] Created workflow that uses both runners
- [ ] Linux job runs on Linux runner
- [ ] Windows job runs on Windows runner
- [ ] Jobs complete successfully
- [ ] Logs are clear and helpful

### Monitoring Setup (Optional)
- [ ] Set up health check monitoring for Linux runner
- [ ] Set up health check monitoring for Windows runner
- [ ] Configured alerts for runner offline
- [ ] Configured alerts for high resource usage
- [ ] Documented how to check runner health

### Security Review
- [ ] `.env` file is not committed to git (check `.gitignore`)
- [ ] GitHub PAT is stored securely
- [ ] PAT is not logged anywhere
- [ ] Resource limits are appropriate
- [ ] Ephemeral mode is enabled (Linux: check `.env`, Windows: default)
- [ ] Only authorized users can access runners
- [ ] Firewall rules reviewed (if applicable)

### Documentation
- [ ] Updated team documentation with:
  - [ ] How to use self-hosted runners in workflows
  - [ ] Available runner labels
  - [ ] Who to contact for runner issues
  - [ ] How to request new runners
- [ ] Created runbook for common issues
- [ ] Documented backup/recovery procedures

## Maintenance Setup

### Scheduled Tasks
- [ ] Set reminder to check runner health (weekly)
- [ ] Set reminder to check for runner updates (monthly)
- [ ] Set reminder to review disk space (monthly)
- [ ] Set reminder to review resource usage (monthly)
- [ ] Set reminder to review security settings (quarterly)

### Backup
- [ ] Backed up `.env` file securely
- [ ] Backed up configuration files
- [ ] Documented how to restore runner
- [ ] Documented how to migrate runner to new host

## Rollback Plan (If Needed)

### Linux Runner Rollback
```bash
# Stop and remove runner
cd ~/github-runners
docker-compose down

# Remove from GitHub (if needed)
# Go to GitHub → Settings → Actions → Runners → Remove

# Clean up
docker system prune
```

### Windows Runner Rollback
```powershell
# Stop service
Stop-Service "actions.runner.*"

# Uninstall service
cd C:\actions-runner
.\svc.cmd uninstall

# Remove from GitHub
.\config.cmd remove --token YOUR_TOKEN

# Clean up
cd \
Remove-Item -Recurse -Force C:\actions-runner
```

## Future Expansion Checklist

When adding more hosts:

- [ ] Reviewed this checklist for new host
- [ ] Determined host type (Linux/Windows/macOS)
- [ ] Verified prerequisites
- [ ] Chose unique runner name
- [ ] Configured appropriate labels
- [ ] Set resource limits based on host capacity
- [ ] Deployed and tested
- [ ] Updated documentation

## Success Criteria

You'll know the deployment is successful when:

✅ Both runners appear as "Idle" in GitHub
✅ Test workflows run successfully on both platforms
✅ Resource usage is within acceptable limits
✅ No errors in runner logs
✅ Runners automatically pick up new jobs
✅ Ephemeral mode working (runners re-register after jobs)
✅ Team can use runners in their workflows
✅ Documentation is complete and accessible

## Troubleshooting Reference

If issues occur, check:

1. **SETUP-GUIDE.md** - Complete setup walkthrough
2. **README.md** - Linux runner details and troubleshooting
3. **README-WINDOWS-NATIVE.md** - Windows runner details and troubleshooting
4. Runner logs:
   - Linux: `docker-compose logs`
   - Windows: `C:\actions-runner\_diag\Runner_*.log`
5. GitHub Actions documentation
6. GitHub runner releases page for known issues

## Notes

- Keep this checklist updated as you learn more about your setup
- Add host-specific notes as needed
- Share learnings with team members
- Update documentation when configuration changes

---

**Good luck with your deployment!** 🚀
