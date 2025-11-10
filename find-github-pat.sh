#!/bin/bash

# Helper script to find and verify the GitHub PAT on bx.ee
# Run this script ON bx.ee after SSHing in

echo "=========================================="
echo "GitHub PAT Finder & Verifier"
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

# Search for vault/secrets directories
echo "Searching for vault/secrets directories..."
echo ""

# Common locations to check
SEARCH_PATHS=(
    "$HOME/secrets"
    "$HOME/vault"
    "$HOME/.secrets"
    "$HOME/.vault"
    "/var/secrets"
    "/var/vault"
    "/opt/secrets"
    "/opt/vault"
    "$HOME/burzmali/secrets"
    "$HOME/burzmali/vault"
)

FOUND_DIRS=()

for path in "${SEARCH_PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo "Found: $path"
        FOUND_DIRS+=("$path")
    fi
done

# Search more broadly if nothing found
if [ ${#FOUND_DIRS[@]} -eq 0 ]; then
    echo "Searching more broadly (this may take a moment)..."
    while IFS= read -r dir; do
        echo "Found: $dir"
        FOUND_DIRS+=("$dir")
    done < <(find $HOME /opt /var -type d \( -name "secrets" -o -name "vault" -o -name "*burzmali*" \) 2>/dev/null | head -20)
fi

if [ ${#FOUND_DIRS[@]} -eq 0 ]; then
    print_error "No secrets/vault directories found"
    echo ""
    echo "Try searching manually:"
    echo "  find \$HOME -type d -name '*secret*' 2>/dev/null"
    echo "  find \$HOME -type d -name '*vault*' 2>/dev/null"
    echo "  find \$HOME -type d -name '*burzmali*' 2>/dev/null"
    exit 1
fi

echo ""
print_status "Found ${#FOUND_DIRS[@]} potential directory(ies)"
echo ""

# Search for files that might contain GitHub PAT
echo "Searching for GitHub-related files..."
echo ""

PAT_FILES=()

for dir in "${FOUND_DIRS[@]}"; do
    # Look for files with github in the name
    while IFS= read -r file; do
        echo "Found file: $file"
        PAT_FILES+=("$file")
    done < <(find "$dir" -type f \( -iname "*github*" -o -iname "*pat*" -o -iname "*token*" \) 2>/dev/null)

    # Look for common secret file names
    for filename in "github" "github.txt" "github_pat" "github_token" "token" "pat" ".env" "secrets.env"; do
        if [ -f "$dir/$filename" ]; then
            echo "Found file: $dir/$filename"
            PAT_FILES+=("$dir/$filename")
        fi
    done
done

if [ ${#PAT_FILES[@]} -eq 0 ]; then
    print_warning "No GitHub-related files found"
    echo ""
    echo "Manual search suggestions:"
    echo "  ls -la ${FOUND_DIRS[0]}"
    for dir in "${FOUND_DIRS[@]}"; do
        echo "  find $dir -type f -exec grep -l 'ghp_' {} \; 2>/dev/null"
    done
else
    echo ""
    print_status "Found ${#PAT_FILES[@]} potential file(s)"
    echo ""

    # Try to extract PAT patterns from files
    echo "Checking files for GitHub PAT patterns (ghp_*)..."
    echo ""

    for file in "${PAT_FILES[@]}"; do
        if [ -r "$file" ]; then
            # Look for PAT pattern (ghp_)
            if grep -q "ghp_" "$file" 2>/dev/null; then
                echo "File contains PAT pattern: $file"
                echo "First few characters:"
                grep -o "ghp_[A-Za-z0-9]*" "$file" 2>/dev/null | head -1 | cut -c1-10
                echo "..."
                echo ""
            fi
        else
            echo "Cannot read file (permissions): $file"
        fi
    done
fi

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Locate the PAT file from the results above"
echo "2. Read the file content: cat /path/to/file"
echo "3. Copy the PAT (starts with ghp_)"
echo "4. Verify it works with the command below"
echo ""
echo "To verify the PAT:"
echo "  export GITHUB_PAT='your_pat_here'"
echo "  curl -H \"Authorization: token \$GITHUB_PAT\" https://api.github.com/user"
echo ""
echo "To check permissions:"
echo "  curl -H \"Authorization: token \$GITHUB_PAT\" https://api.github.com/orgs/jgowdy"
echo ""
