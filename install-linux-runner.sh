#!/bin/bash

# GitHub Actions Runner - Native Linux Installation
# For bx.ee production server

set -e

echo "=========================================="
echo "GitHub Actions Runner - Native Linux Install"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Configuration
ORG_NAME="TeamEightStar"
RUNNER_NAME="bx-ee-runner-1"
LABELS="bx-ee,linux,native,docker"
RUNNER_GROUP="default"
GITHUB_PAT="ghp_YOUR_TOKEN_HERE"

echo "Configuration:"
echo "  Organization: $ORG_NAME"
echo "  Runner Name: $RUNNER_NAME"
echo "  Labels: $LABELS"
echo ""

# Create runner directory
RUNNER_DIR="/opt/actions-runner"
if [ -d "$RUNNER_DIR" ]; then
    print_warning "Runner directory already exists"
else
    echo "Creating runner directory: $RUNNER_DIR"
    mkdir -p "$RUNNER_DIR"
    print_status "Runner directory created"
fi

cd "$RUNNER_DIR"

# Download latest runner
echo ""
echo "Downloading latest GitHub Actions runner..."

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    RUNNER_ARCH="linux-x64"
elif [ "$ARCH" = "aarch64" ]; then
    RUNNER_ARCH="linux-arm64"
else
    print_error "Unsupported architecture: $ARCH"
    exit 1
fi

print_status "Detected architecture: $ARCH (using $RUNNER_ARCH)"

# Get latest version
LATEST_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    print_error "Failed to fetch latest runner version"
    exit 1
fi

print_status "Latest version: $LATEST_VERSION"

# Download
RUNNER_FILE="actions-runner-${RUNNER_ARCH}-${LATEST_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/${RUNNER_FILE}"

echo "Downloading from: $RUNNER_URL"
curl -L -o "$RUNNER_FILE" "$RUNNER_URL"
print_status "Download complete"

# Extract
echo "Extracting runner..."
tar xzf "$RUNNER_FILE"
rm "$RUNNER_FILE"
print_status "Runner extracted"

# Get registration token
echo ""
echo "Getting registration token from GitHub..."

TOKEN_URL="https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token"
RUNNER_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github.v3+json" \
    "$TOKEN_URL" | grep '"token":' | sed -E 's/.*"token": "([^"]+)".*/\1/')

if [ -z "$RUNNER_TOKEN" ]; then
    print_error "Failed to get registration token"
    exit 1
fi

print_status "Registration token obtained"

# Configure runner
echo ""
echo "Configuring runner..."

./config.sh \
    --url "https://github.com/$ORG_NAME" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --work "_work" \
    --ephemeral \
    --unattended

if [ $? -eq 0 ]; then
    print_status "Runner configured successfully"
else
    print_error "Runner configuration failed"
    exit 1
fi

# Install as service
echo ""
echo "Installing runner as systemd service..."

./svc.sh install
./svc.sh start

print_status "Runner installed and started as service"

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Runner is now running as a systemd service"
echo ""
echo "Commands:"
echo "  Status: sudo ./svc.sh status"
echo "  Stop:   sudo ./svc.sh stop"
echo "  Start:  sudo ./svc.sh start"
echo "  Logs:   sudo journalctl -u actions.runner.* -f"
echo ""
echo "Verify in GitHub:"
echo "  https://github.com/organizations/$ORG_NAME/settings/actions/runners"
echo ""
