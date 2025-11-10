#!/bin/bash

# GitHub Actions Runner Health Check Script

set -e

echo "=========================================="
echo "GitHub Actions Runner Health Check"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if runner container exists
if docker ps -a --format '{{.Names}}' | grep -q "github-runner-bx-ee"; then
    print_status "Runner container exists"

    # Check if running
    if docker ps --format '{{.Names}}' | grep -q "github-runner-bx-ee"; then
        print_status "Runner container is running"

        # Check health status
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' github-runner-bx-ee 2>/dev/null || echo "none")
        if [ "$HEALTH" = "healthy" ]; then
            print_status "Runner is healthy"
        elif [ "$HEALTH" = "none" ]; then
            print_warning "No health check configured or not ready yet"
        else
            print_warning "Runner health status: $HEALTH"
        fi

        # Show resource usage
        echo ""
        echo "Current resource usage:"
        docker stats --no-stream github-runner-bx-ee

        # Show recent logs
        echo ""
        echo "Recent logs (last 20 lines):"
        echo "=========================================="
        docker-compose logs --tail=20 github-runner

    else
        print_error "Runner container is not running"
        echo ""
        echo "Container status:"
        docker ps -a | grep github-runner-bx-ee
        echo ""
        echo "Recent logs:"
        docker-compose logs --tail=30 github-runner
        exit 1
    fi
else
    print_error "Runner container does not exist"
    echo "Have you deployed the runner yet? Run: ./deploy.sh"
    exit 1
fi

echo ""
echo "=========================================="
echo "To view live logs: docker-compose logs -f"
echo "To restart runner: docker-compose restart"
echo "To check GitHub: https://github.com/organizations/jgowdy/settings/actions/runners"
echo "=========================================="
