#!/bin/bash

# GitHub Actions Runner Deployment Script
# Use this script for safer deployment on production hosts

set -e  # Exit on error

echo "=========================================="
echo "GitHub Actions Runner Deployment Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found!"
    echo "Please copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

print_status ".env file found"

# Check if GITHUB_PAT is configured
if grep -q "your_github_personal_access_token_here" .env; then
    print_error "GITHUB_PAT not configured in .env file!"
    echo "Please edit .env and set your GitHub Personal Access Token"
    exit 1
fi

print_status "GITHUB_PAT appears to be configured"

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running!"
    exit 1
fi

print_status "Docker is running"

# Check disk space
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    print_warning "Available disk space is less than 10GB (${AVAILABLE_SPACE}GB)"
    echo "Continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_status "Sufficient disk space available (${AVAILABLE_SPACE}GB)"
fi

# Validate docker-compose.yml
echo ""
echo "Validating docker-compose.yml..."
if docker-compose config > /dev/null 2>&1; then
    print_status "docker-compose.yml is valid"
else
    print_error "docker-compose.yml validation failed!"
    exit 1
fi

# Show resource limits
echo ""
echo "Current resource limits from .env:"
source .env
echo "  CPU Limit: ${CPU_LIMIT:-2.0} cores"
echo "  Memory Limit: ${MEMORY_LIMIT:-2G}"
echo "  Runner Name: ${RUNNER_NAME:-bx-ee-runner-1}"
echo "  Labels: ${LABELS:-bx-ee,docker,linux}"

# Confirmation
echo ""
print_warning "This will deploy the GitHub Actions runner on this host"
echo "Are you ready to proceed? (y/N)"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Check if runner is already running
if docker-compose ps | grep -q "Up"; then
    print_warning "Runner appears to be already running"
    echo "Do you want to restart it? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Stopping existing runner..."
        docker-compose down
        print_status "Existing runner stopped"
    else
        echo "Deployment cancelled"
        exit 0
    fi
fi

# Deploy the runner
echo ""
echo "Starting GitHub Actions runner..."
docker-compose up -d

if [ $? -eq 0 ]; then
    print_status "Runner deployed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Check logs: docker-compose logs -f"
    echo "2. Verify in GitHub: https://github.com/organizations/${ORG_NAME}/settings/actions/runners"
    echo "3. Monitor resources: docker stats github-runner-bx-ee"
    echo ""

    # Wait a few seconds and show initial logs
    echo "Showing initial logs (Ctrl+C to exit)..."
    sleep 3
    docker-compose logs --tail=50 -f
else
    print_error "Deployment failed!"
    exit 1
fi
