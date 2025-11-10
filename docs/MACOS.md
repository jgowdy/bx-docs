# GitHub Actions Runner - Native macOS Installation

For **native macOS builds** (Xcode, Swift, iOS/macOS apps, etc.), install the GitHub Actions runner directly on macOS.

## Why Native Installation?

- **Xcode access** - Required for iOS/macOS development
- **Code signing** - Access to keychain and certificates
- **macOS frameworks** - Native access to Apple frameworks
- **Best performance** - No virtualization overhead
- **Metal/GPU access** - For graphics-intensive builds

## Prerequisites

### macOS Requirements:
- macOS 10.15 (Catalina) or later
- Bash shell (pre-installed)
- Network access to GitHub
- Administrator access (for service installation)
- Development tools installed (Xcode, command line tools, etc.)

### GitHub Requirements:
- GitHub Personal Access Token (PAT) with `admin:org` scope
- Organization admin access

## Quick Installation

### Option 1: Automated Script (Recommended)

1. **Ensure you're in the correct directory**:
   ```bash
   cd ~/path/to/bx-pool
   ```

2. **Make the script executable**:
   ```bash
   chmod +x install-macos-runner.sh
   ```

3. **Review configuration** (optional):
   ```bash
   nano install-macos-runner.sh

   # Edit these variables at the top:
   ORG_NAME="jgowdy"           # Your organization
   RUNNER_NAME="..."           # Runner name (default uses hostname)
   LABELS="macos,native,..."   # Labels for targeting workflows
   ```

4. **Run the installation script**:
   ```bash
   ./install-macos-runner.sh
   ```

5. **Enter your GitHub PAT** when prompted

6. **Choose service installation method**:
   - **Option 1 (LaunchDaemon)**: Runs at boot, doesn't require user login (recommended for dedicated build machines)
   - **Option 2 (LaunchAgent)**: Runs when user logs in (good for workstations)
   - **Option 3 (Manual)**: No service, run manually (for testing)

The script will:
- Detect your Mac's architecture (Apple Silicon or Intel)
- Download the appropriate runner binary
- Get a registration token from GitHub
- Configure the runner with ephemeral mode
- Optionally install as a service
- Start the runner

### Option 2: Manual Installation

1. **Create runner directory**:
   ```bash
   mkdir -p ~/actions-runner
   cd ~/actions-runner
   ```

2. **Download latest runner**:
   ```bash
   # For Apple Silicon (M1/M2/M3)
   ARCH="osx-arm64"

   # For Intel
   # ARCH="osx-x64"

   # Get latest version
   VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

   # Download
   curl -o actions-runner.tar.gz -L "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-${ARCH}-${VERSION}.tar.gz"

   # Extract
   tar xzf actions-runner.tar.gz
   rm actions-runner.tar.gz
   ```

3. **Get registration token** from GitHub API:
   ```bash
   curl -X POST \
     -H "Authorization: token YOUR_PAT_HERE" \
     -H "Accept: application/vnd.github.v3+json" \
     https://api.github.com/orgs/jgowdy/actions/runners/registration-token
   ```

4. **Configure runner**:
   ```bash
   ./config.sh \
     --url https://github.com/jgowdy \
     --token YOUR_REGISTRATION_TOKEN \
     --name $(hostname)-runner \
     --labels "macos,native,xcode,$(uname -m)" \
     --runnergroup default \
     --work _work \
     --ephemeral \
     --unattended
   ```

5. **Install as service** (optional):
   ```bash
   # As LaunchDaemon (runs at boot)
   sudo ./svc.sh install
   sudo ./svc.sh start

   # Or as LaunchAgent (runs at login)
   ./svc.sh install $USER
   ./svc.sh start
   ```

## Architecture Detection

The runner automatically detects your Mac's architecture:

- **Apple Silicon** (M1/M2/M3): Uses `osx-arm64` runner and adds `arm64` label
- **Intel**: Uses `osx-x64` runner and adds `x86_64` label

This allows you to target specific architectures in workflows:

```yaml
jobs:
  build-arm64:
    runs-on: [self-hosted, macos, arm64]

  build-intel:
    runs-on: [self-hosted, macos, x86_64]
```

## Verification

1. **Check service status** (if installed as service):
   ```bash
   cd ~/actions-runner
   ./svc.sh status
   ```

2. **View logs**:
   ```bash
   tail -f ~/actions-runner/_diag/Runner_*.log
   ```

3. **Check in GitHub**:
   - Visit: `https://github.com/organizations/jgowdy/settings/actions/runners`
   - Your macOS runner should appear as "Idle"

4. **Check system info**:
   ```bash
   # Architecture
   uname -m

   # macOS version
   sw_vers

   # Xcode version
   xcodebuild -version
   ```

## Using the Runner in Workflows

### Basic macOS Build

```yaml
name: macOS Build
on: [push]

jobs:
  build:
    runs-on: [self-hosted, macos]

    steps:
      - uses: actions/checkout@v3

      - name: Build
        run: swift build

      - name: Test
        run: swift test
```

### iOS Build with Xcode

```yaml
name: iOS Build
on: [push]

jobs:
  build:
    runs-on: [self-hosted, macos, xcode]

    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Build
        run: |
          xcodebuild -scheme MyApp \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            build

      - name: Run tests
        run: |
          xcodebuild -scheme MyApp \
            -configuration Debug \
            -destination 'platform=iOS Simulator,name=iPhone 14' \
            test
```

### Universal Binary (Apple Silicon + Intel)

```yaml
name: Universal Binary Build
on: [push]

jobs:
  build-arm64:
    runs-on: [self-hosted, macos, arm64]
    steps:
      - uses: actions/checkout@v3
      - name: Build ARM64
        run: swift build -c release --arch arm64
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: binary-arm64
          path: .build/release/MyApp

  build-x86_64:
    runs-on: [self-hosted, macos, x86_64]
    steps:
      - uses: actions/checkout@v3
      - name: Build x86_64
        run: swift build -c release --arch x86_64
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: binary-x86_64
          path: .build/release/MyApp

  create-universal:
    needs: [build-arm64, build-x86_64]
    runs-on: [self-hosted, macos]
    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v3
      - name: Create universal binary
        run: lipo -create binary-arm64/MyApp binary-x86_64/MyApp -output MyApp-universal
      - name: Upload universal binary
        uses: actions/upload-artifact@v3
        with:
          name: universal-binary
          path: MyApp-universal
```

## Managing the Runner

### Check Status
```bash
cd ~/actions-runner

# Service status (if installed as service)
./svc.sh status

# Or check with launchctl
launchctl list | grep actions.runner
```

### View Logs
```bash
# Runner logs
tail -f ~/actions-runner/_diag/Runner_*.log

# Worker logs (job execution)
tail -f ~/actions-runner/_diag/Worker_*.log
```

### Stop/Start Service
```bash
cd ~/actions-runner

# Stop
sudo ./svc.sh stop    # If LaunchDaemon
./svc.sh stop         # If LaunchAgent

# Start
sudo ./svc.sh start   # If LaunchDaemon
./svc.sh start        # If LaunchAgent

# Check status
./svc.sh status
```

### Update Runner

```bash
cd ~/actions-runner

# Stop service (if installed)
sudo ./svc.sh stop    # Or without sudo for LaunchAgent
./svc.sh uninstall

# Remove runner from GitHub (optional)
./config.sh remove --token YOUR_TOKEN

# Download new version (see manual installation steps above)

# Reconfigure and reinstall service
# (Follow configuration steps above)
```

### Uninstall Runner

```bash
cd ~/actions-runner

# Stop service
sudo ./svc.sh stop    # Or without sudo for LaunchAgent

# Uninstall service
sudo ./svc.sh uninstall    # Or without sudo for LaunchAgent

# Remove runner from GitHub
./config.sh remove --token YOUR_TOKEN

# Delete directory
cd ~
rm -rf ~/actions-runner
```

## Configuration Options

### Runner Labels

Common labels for macOS runners:

- `macos` - macOS operating system
- `native` - Native (not virtualized)
- `xcode` - Xcode installed
- `arm64` or `x86_64` - Architecture
- `monterey`, `ventura`, `sonoma` - macOS version
- Custom labels for specific tools/SDKs

Example: `macos,native,xcode,arm64,sonoma`

### Service Types

**LaunchDaemon** (requires sudo):
- Runs at system boot
- Runs even when no user is logged in
- Best for dedicated build machines
- Installed system-wide

**LaunchAgent**:
- Runs when user logs in
- Requires user session
- Good for development machines
- Installed per-user

**Manual** (no service):
- Run with `./run.sh` when needed
- Good for testing
- Must be started manually

## Development Environment Setup

### Install Xcode

1. **Install from App Store**:
   ```bash
   # Open App Store and install Xcode
   open -a "App Store"
   ```

2. **Or download from developer.apple.com**

3. **Install Command Line Tools**:
   ```bash
   xcode-select --install
   ```

4. **Accept license**:
   ```bash
   sudo xcodebuild -license accept
   ```

### Install Homebrew (Optional)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install Additional Tools

```bash
# Node.js
brew install node

# Python
brew install python@3.11

# Ruby (for CocoaPods)
brew install ruby

# CocoaPods
sudo gem install cocoapods

# fastlane (for iOS automation)
brew install fastlane
```

## Code Signing for iOS

### Setup for Automated Builds

1. **Create a keychain for the runner**:
   ```bash
   security create-keychain -p PASSWORD runner.keychain
   security default-keychain -s runner.keychain
   security unlock-keychain -p PASSWORD runner.keychain
   security set-keychain-settings -t 3600 -u runner.keychain
   ```

2. **Import certificates**:
   ```bash
   security import cert.p12 -k runner.keychain -P CERT_PASSWORD -T /usr/bin/codesign
   security set-key-partition-list -S apple-tool:,apple: -s -k PASSWORD runner.keychain
   ```

3. **In workflow, use the keychain**:
   ```yaml
   - name: Setup keychain
     run: |
       security unlock-keychain -p ${{ secrets.KEYCHAIN_PASSWORD }} runner.keychain
       security set-keychain-settings -t 3600 -u runner.keychain
   ```

## Performance Tuning

### Disk Space Management

```bash
# Check work directory size
du -sh ~/actions-runner/_work

# Clean old job directories (older than 7 days)
find ~/actions-runner/_work -type d -name "_temp" -mtime +7 -exec rm -rf {} \;

# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean Homebrew cache
brew cleanup
```

### Resource Monitoring

```bash
# Monitor runner process
ps aux | grep Runner.Listener

# Monitor CPU/Memory
top -pid $(pgrep -f Runner.Listener)

# Disk usage
df -h

# Network activity
nettop -p Runner.Listener
```

## Security Considerations

### Keychain Access
- Use dedicated keychain for runner
- Set appropriate timeout
- Secure keychain password in environment or secrets

### File Permissions
- Runner runs as the user who installed it (LaunchAgent) or root (LaunchDaemon)
- Ensure proper permissions on sensitive files
- Consider using a dedicated user account

### Network Security
- Requires outbound HTTPS to GitHub
- Configure firewall if needed
- No inbound connections required

### Code Execution
- Workflows run with runner's user permissions
- Has access to keychain and certificates
- **Only run trusted workflows**

## Troubleshooting

### Service Won't Start

1. Check service logs:
   ```bash
   # For LaunchDaemon
   sudo cat /Library/LaunchDaemons/actions.runner.*.plist
   sudo tail -f /var/log/system.log | grep runner

   # For LaunchAgent
   cat ~/Library/LaunchAgents/actions.runner.*.plist
   log show --predicate 'process == "Runner.Listener"' --last 1h
   ```

2. Check permissions:
   ```bash
   ls -la ~/actions-runner
   ```

3. Manually run to see errors:
   ```bash
   cd ~/actions-runner
   ./run.sh
   ```

### Runner Shows Offline

1. Check service is running
2. Check network connectivity:
   ```bash
   ping github.com
   curl -I https://api.github.com
   ```
3. Check runner logs for errors

### Xcode Build Failures

1. Verify Xcode is installed:
   ```bash
   xcodebuild -version
   ```

2. Check selected Xcode:
   ```bash
   xcode-select -p
   ```

3. Accept license:
   ```bash
   sudo xcodebuild -license accept
   ```

4. Check simulators:
   ```bash
   xcrun simctl list
   ```

### Disk Space Issues

```bash
# Check disk space
df -h

# Find large files
du -sh ~/actions-runner/_work/*
du -sh ~/Library/Developer/Xcode/DerivedData/*

# Clean up
rm -rf ~/actions-runner/_work/_temp
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

## Monitoring and Maintenance

### Health Check Script

```bash
#!/bin/bash
# check-macos-runner.sh

if pgrep -f "Runner.Listener" > /dev/null; then
    echo "✓ Runner is running"

    # Check disk space
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $DISK_USAGE -gt 80 ]; then
        echo "⚠ Disk usage is high: ${DISK_USAGE}%"
    fi

    # Check work directory size
    WORK_SIZE=$(du -sh ~/actions-runner/_work 2>/dev/null | awk '{print $1}')
    echo "Work directory size: $WORK_SIZE"

else
    echo "✗ Runner is not running!"
    exit 1
fi
```

### Regular Maintenance

- **Weekly**: Check runner status and logs
- **Monthly**: Clean derived data and caches
- **Monthly**: Check for macOS and Xcode updates
- **Quarterly**: Review and update installed tools
- **Quarterly**: Review security settings

## Production Deployment Checklist

- [ ] macOS is up to date
- [ ] Xcode is installed and configured
- [ ] Command line tools installed
- [ ] GitHub PAT created with correct permissions
- [ ] Runner installed and configured
- [ ] Service installed and running (if applicable)
- [ ] Runner appears in GitHub as "Idle"
- [ ] Xcode license accepted
- [ ] Code signing certificates imported (if needed)
- [ ] Test workflow executed successfully
- [ ] Monitoring configured
- [ ] Documentation updated

## Support Resources

- GitHub Actions docs: https://docs.github.com/en/actions/hosting-your-own-runners
- Runner releases: https://github.com/actions/runner/releases
- Apple Developer: https://developer.apple.com
- Xcode docs: https://developer.apple.com/documentation/xcode

## Upgrading macOS

When upgrading macOS:

1. Stop the runner service
2. Perform macOS upgrade
3. Verify Xcode still works
4. Re-accept Xcode license if needed
5. Restart runner service
6. Test with a workflow

```bash
# Before upgrade
cd ~/actions-runner
sudo ./svc.sh stop    # Or without sudo for LaunchAgent

# After upgrade
sudo xcodebuild -license accept
sudo ./svc.sh start   # Or without sudo for LaunchAgent
```
