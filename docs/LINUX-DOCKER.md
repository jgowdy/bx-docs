# GitHub Actions Runner - Linux Docker Installation

Deploy GitHub Actions self-hosted runners on Linux using Docker Compose.

## Prerequisites

### On Linux Host (e.g., bx.ee):
- Docker installed and running
- Docker Compose installed  
- Network access to GitHub (github.com and api.github.com)
- Sufficient resources (CPU, memory, disk space)

### GitHub Requirements:
- GitHub Personal Access Token (PAT) with `admin:org` scope
- Organization admin access to register runners

## Installation

### 1. Download Files

```bash
mkdir -p ~/github-runners
cd ~/github-runners

# Download docker-compose.yml, .env.example, deploy.sh, check-runner.sh
```

### 2. Configure Environment

```bash
# Copy example config
cp .env.example .env

# Edit with your values
nano .env
```

**Required configuration:**

```bash
# GitHub authentication
GITHUB_PAT=ghp_your_token_here
ORG_NAME=jgowdy

# Runner configuration
RUNNER_NAME=bx-ee-runner-1  # Unique name
LABELS=bx-ee,docker,linux,x64

# Resource limits (adjust for your host)
CPU_LIMIT=4.0      # Number of CPU cores
MEMORY_LIMIT=8g    # Memory limit
```

### 3. Review docker-compose.yml

The configuration uses:
- `myoung34/github-runner` image
- Ephemeral mode (secure - runner re-registers after each job)
- Resource limits to prevent runaway jobs
- Automatic restart policy

### 4. Deploy

```bash
# Make scripts executable
chmod +x deploy.sh check-runner.sh

# Deploy
./deploy.sh

# Verify
docker-compose ps
docker-compose logs
```

### 5. Verify in GitHub

Check runner status at:
https://github.com/organizations/jgowdy/settings/actions/runners

Runner should show as "Idle" (green).

## Management

### Check Status

```bash
docker-compose ps
docker-compose logs -f
```

### Restart

```bash
docker-compose restart
```

### Stop

```bash
docker-compose down
```

### Update

```bash
docker-compose pull
docker-compose up -d
```

### View Logs

```bash
# Follow logs
docker-compose logs -f

# Last 50 lines
docker-compose logs --tail=50

# Search logs
docker-compose logs | grep ERROR
```

## Using in Workflows

Target this runner using labels:

```yaml
name: Build on bx.ee
on: [push]

jobs:
  build:
    runs-on: [self-hosted, linux, docker, bx-ee]
    steps:
      - uses: actions/checkout@v4
      - run: echo "Building on bx.ee"
```

## Troubleshooting

### Runner Not Appearing

```bash
# Check logs for errors
docker-compose logs

# Verify PAT has correct scope
# Verify ORG_NAME is correct
# Check network connectivity to github.com
```

### Runner Shows Offline

```bash
# Check container is running
docker-compose ps

# Restart
docker-compose restart

# Check logs
docker-compose logs -f
```

### High Resource Usage

```bash
# Check resource usage
docker stats

# Adjust limits in .env
CPU_LIMIT=2.0
MEMORY_LIMIT=4g

# Restart with new limits
docker-compose up -d
```

### Network Issues

```bash
# Test connectivity
docker-compose exec runner ping github.com

# Check DNS
docker-compose exec runner nslookup api.github.com
```

## Resource Planning

### Recommended Limits

| Host Resources | Runner Limit | Why |
|----------------|--------------|-----|
| 16 cores | 4-8 cores | Leave headroom for OS |
| 32GB RAM | 8-16GB | Prevent OOM kills |
| 500GB disk | Monitor usage | Logs and cache grow |

### Monitoring

```bash
# Check disk usage
docker system df

# Clean up old images
docker system prune -a

# Check resource usage
docker stats
```

## Security

- Store `.env` file securely (use `.gitignore`)
- Rotate GitHub PAT regularly
- Use ephemeral runners when possible
- Set resource limits to prevent abuse
- Monitor runner logs for suspicious activity

## Advanced Configuration

### Multiple Runners

Run multiple runners on same host:

```bash
# Create separate directories
mkdir runner-1 runner-2

# Configure each with unique RUNNER_NAME
cd runner-1
nano .env  # RUNNER_NAME=bx-ee-runner-1

cd ../runner-2  
nano .env  # RUNNER_NAME=bx-ee-runner-2

# Deploy each
cd runner-1 && docker-compose up -d
cd ../runner-2 && docker-compose up -d
```

### Custom Docker Network

```yaml
# docker-compose.yml
networks:
  github-runners:
    name: github-runners
    driver: bridge

services:
  runner:
    networks:
      - github-runners
```

### Volume Mounts

Mount workspace for persistent builds:

```yaml
services:
  runner:
    volumes:
      - /home/builder/workspace:/workspace
```

## Backup and Recovery

### Backup Configuration

```bash
# Backup .env
cp .env .env.backup

# Store securely (encrypted)
```

### Disaster Recovery

```bash
# 1. Install Docker on new host
# 2. Copy .env file
# 3. Run ./deploy.sh
# 4. Runner re-registers automatically
```

## Performance Tips

1. **Use SSD** for Docker storage
2. **Set resource limits** appropriate for workload
3. **Monitor logs** for performance issues
4. **Clean up** regularly (`docker system prune`)
5. **Use caching** in workflows to speed builds

## Support

- GitHub Actions: https://docs.github.com/en/actions
- Docker Runner: https://github.com/myoung34/docker-github-actions-runner
- Organization Runners: https://github.com/organizations/jgowdy/settings/actions/runners
