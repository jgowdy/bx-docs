# GitHub Actions Self-Hosted Runners

Docker and native installations for GitHub Actions self-hosted runners across multiple platforms.

## Overview

- **Organization**: jgowdy
- **Primary Host**: bx.ee (Linux production server)
- **Management**: Docker Compose (Linux) or Native Service (Windows/macOS)

## Quick Start

### Prerequisites

1. **GitHub Personal Access Token (PAT)** with `admin:org` scope
   - Go to GitHub Settings → Developer Settings → Personal Access Tokens
   - Generate token with organization admin permissions
   - Save securely

2. **Platform Requirements**:
   - Linux: Docker + Docker Compose
   - Windows: PowerShell 5.0+, Administrator access
   - macOS: Homebrew, Administrator access

### Choose Your Platform

| Platform | Installation Method | Documentation |
|----------|-------------------|---------------|
| **Linux (Docker)** | Docker Compose | [docs/LINUX-DOCKER.md](docs/LINUX-DOCKER.md) |
| **Windows (Docker)** | Docker Compose | [docs/WINDOWS-DOCKER.md](docs/WINDOWS-DOCKER.md) |
| **Windows (Native)** | Native Service | [docs/WINDOWS-NATIVE.md](docs/WINDOWS-NATIVE.md) |
| **macOS (Native)** | Native Service | [docs/MACOS.md](docs/MACOS.md) |

### Linux Quick Install (Docker)

```bash
# 1. Clone or download this repo
cd ~/github-runners

# 2. Configure
cp .env.example .env
nano .env  # Set GITHUB_PAT, ORG_NAME, RUNNER_NAME, LABELS

# 3. Deploy
./deploy.sh

# 4. Verify
docker-compose ps
docker-compose logs
```

Runner should appear as "Idle" at: https://github.com/organizations/jgowdy/settings/actions/runners

## Documentation

- **[Setup Guide](docs/SETUP-GUIDE.md)** - Detailed setup for all platforms
- **[Deployment Checklist](docs/DEPLOYMENT-CHECKLIST.md)** - Pre-deployment verification
- **Platform-Specific Docs**:
  - [Linux Docker](docs/LINUX-DOCKER.md)
  - [Windows Docker](docs/WINDOWS-DOCKER.md)
  - [Windows Native](docs/WINDOWS-NATIVE.md)
  - [macOS Native](docs/MACOS.md)

## Management

### Check Runner Status

```bash
# Linux (Docker)
docker-compose ps
docker-compose logs -f

# Windows/macOS (Native)
# Check GitHub: https://github.com/organizations/jgowdy/settings/actions/runners
```

### Restart Runner

```bash
# Linux (Docker)
docker-compose restart

# Windows (Native)
Restart-Service "actions.runner.*"

# macOS (Native)
brew services restart actions-runner
```

### Update Runner

```bash
# Linux (Docker)
docker-compose pull
docker-compose up -d

# Windows/macOS (Native)
# Re-run installation script
```

## Troubleshooting

### Runner Not Appearing in GitHub

1. Check PAT has `admin:org` scope
2. Verify organization name is correct
3. Check runner logs for errors
4. Ensure network access to github.com

### Runner Shows "Offline"

1. Check container/service is running
2. Verify network connectivity
3. Check logs for errors
4. Restart runner

### Build Failures

1. Check runner labels match workflow requirements
2. Verify build tools are installed
3. Review workflow logs
4. Check resource limits (CPU/memory)

## Architecture

```
GitHub Actions Workflow
    ↓
GitHub Actions API
    ↓
Self-Hosted Runner (bx.ee, Windows VM, etc.)
    ↓
Build/Test/Deploy
```

### Runner Configuration

- **Ephemeral**: Runners re-register after each job (more secure)
- **Labels**: Target specific runners in workflows (e.g., `runs-on: [self-hosted, linux, docker]`)
- **Resource Limits**: Set CPU/memory limits to prevent runaway jobs

## Security

- Store PAT securely (password manager, encrypted notes)
- Use `.gitignore` to prevent committing `.env` files
- Set resource limits to prevent abuse
- Use ephemeral runners when possible
- Review runner logs regularly

## Contributing

When adding new runners:

1. Follow [DEPLOYMENT-CHECKLIST.md](docs/DEPLOYMENT-CHECKLIST.md)
2. Use unique runner names
3. Set appropriate labels
4. Test with simple workflow first
5. Document any platform-specific requirements

## Support

- GitHub Actions Documentation: https://docs.github.com/en/actions
- GitHub Runners: https://github.com/actions/runner
- Organization Runners: https://github.com/organizations/jgowdy/settings/actions/runners
