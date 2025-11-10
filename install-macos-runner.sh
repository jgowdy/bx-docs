#!/bin/bash

# GitHub Actions Runner - Native macOS Installation
# This script installs the GitHub Actions runner as a macOS LaunchDaemon
# For native macOS builds (Xcode, Swift, etc.)

set -e

echo "=========================================="
echo "GitHub Actions Runner - Native macOS Install"
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

# Configuration - EDIT THESE VALUES
ORG_NAME="TeamEightStar"
RUNNER_NAME="${HOSTNAME}-runner"  # Uses hostname
LABELS="macos,native,xcode,build,$(uname -m)"  # Includes architecture (arm64 or x86_64)
RUNNER_GROUP="default"

echo "Configuration:"
echo "  Organization: $ORG_NAME"
echo "  Runner Name: $RUNNER_NAME"
echo "  Labels: $LABELS"
echo ""

# Prompt for GitHub PAT
echo "Enter your GitHub Personal Access Token (PAT):"
read -s GITHUB_PAT
echo ""

if [ -z "$GITHUB_PAT" ]; then
    print_error "GitHub PAT is required!"
    exit 1
fi

print_status "GitHub PAT provided"

# Create runner directory
RUNNER_DIR="$HOME/actions-runner"
if [ -d "$RUNNER_DIR" ]; then
    print_warning "Runner directory already exists: $RUNNER_DIR"
    echo "Continue and potentially overwrite? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    echo "Creating runner directory: $RUNNER_DIR"
    mkdir -p "$RUNNER_DIR"
    print_status "Runner directory created"
fi

# Download latest runner
echo ""
echo "Downloading latest GitHub Actions runner..."
cd "$RUNNER_DIR"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    RUNNER_ARCH="osx-arm64"
elif [ "$ARCH" = "x86_64" ]; then
    RUNNER_ARCH="osx-x64"
else
    print_error "Unsupported architecture: $ARCH"
    exit 1
fi

print_status "Detected architecture: $ARCH (using $RUNNER_ARCH)"

# Get latest runner version
echo "Fetching latest runner version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    print_error "Failed to fetch latest runner version"
    exit 1
fi

print_status "Latest version: $LATEST_VERSION"

# Download runner
RUNNER_FILE="actions-runner-${RUNNER_ARCH}-${LATEST_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/${RUNNER_FILE}"

echo "Downloading from: $RUNNER_URL"
if curl -L -o "$RUNNER_FILE" "$RUNNER_URL"; then
    print_status "Download complete"
else
    print_error "Download failed"
    exit 1
fi

# Extract runner
echo "Extracting runner..."
tar xzf "$RUNNER_FILE"
rm "$RUNNER_FILE"
print_status "Runner extracted"

# Get registration token from GitHub
echo ""
echo "Getting registration token from GitHub..."

TOKEN_URL="https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token"
RUNNER_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github.v3+json" \
    "$TOKEN_URL" | grep '"token":' | sed -E 's/.*"token": "([^"]+)".*/\1/')

if [ -z "$RUNNER_TOKEN" ]; then
    print_error "Failed to get registration token"
    echo ""
    echo "Common causes:"
    echo "  - Invalid PAT"
    echo "  - PAT missing 'admin:org' scope"
    echo "  - Incorrect organization name"
    echo "  - Network connectivity issues"
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

# Install as LaunchDaemon (runs at boot, without user login)
echo ""
echo "Would you like to install the runner as a service? (recommended)"
echo "Options:"
echo "  1) LaunchDaemon (runs at boot, no user login required)"
echo "  2) LaunchAgent (runs when user logs in)"
echo "  3) Skip (run manually with ./run.sh)"
echo ""
echo "Enter choice (1/2/3):"
read -r service_choice

if [ "$service_choice" = "1" ]; then
    echo "Installing as LaunchDaemon (requires sudo)..."
    sudo ./svc.sh install
    sudo ./svc.sh start
    print_status "Runner installed and started as LaunchDaemon"

elif [ "$service_choice" = "2" ]; then
    echo "Installing as LaunchAgent..."
    ./svc.sh install "$USER"
    ./svc.sh start
    print_status "Runner installed and started as LaunchAgent"

else
    print_warning "Skipping service installation"
    echo "To run the runner manually: cd $RUNNER_DIR && ./run.sh"
fi

# Final verification
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify runner in GitHub:"
echo "   https://github.com/organizations/$ORG_NAME/settings/actions/runners"
echo ""

if [ "$service_choice" = "1" ] || [ "$service_choice" = "2" ]; then
    echo "2. Check service status:"
    echo "   ./svc.sh status"
    echo ""
fi

echo "3. View runner logs:"
echo "   tail -f $RUNNER_DIR/_diag/Runner_*.log"
echo ""
echo "4. Test with a workflow:"
echo "   runs-on: [self-hosted, macos, $(uname -m)]"
echo ""

# Show architecture info
echo "Runner information:"
echo "  Architecture: $(uname -m)"
echo "  macOS Version: $(sw_vers -productVersion)"
echo "  Xcode Version: $(xcodebuild -version 2>/dev/null | head -n 1 || echo 'Not installed')"
echo ""

print_status "Setup complete!"
