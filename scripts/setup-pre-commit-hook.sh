#!/bin/bash
#
# Setup script for SwiftLint pre-commit hook
# Run this script after cloning the repository
#

set -e

echo "🚀 Setting up SwiftLint pre-commit hook..."

# Check if we are in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: This script must be run from the root of a git repository."
    exit 1
fi

# Check if SwiftLint is installed
if ! command -v swiftlint >/dev/null 2>&1; then
    echo "⚠️  SwiftLint is not installed. Installing via Homebrew..."
    if command -v brew >/dev/null 2>&1; then
        brew install swiftlint
    else
        echo "❌ Homebrew is not installed. Please install SwiftLint manually:"
        echo "   Visit: https://github.com/realm/SwiftLint"
        exit 1
    fi
fi

# Copy pre-commit hook
PRE_COMMIT_HOOK=".git/hooks/pre-commit"

if [ -f "$PRE_COMMIT_HOOK" ]; then
    echo "⚠️  Pre-commit hook already exists. Backing up to pre-commit.backup"
    cp "$PRE_COMMIT_HOOK" "$PRE_COMMIT_HOOK.backup"
fi

# Create the pre-commit hook
cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/sh
#
# SwiftLint Pre-commit Hook
# This hook runs SwiftLint on all Swift files before each commit
#

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

echo "${YELLOW}Running SwiftLint...${NC}"

# Check if swiftlint is installed
if ! command -v swiftlint >/dev/null 2>&1; then
    echo "${RED}Error: SwiftLint is not installed.${NC}"
    echo "Please install SwiftLint:"
    echo "  brew install swiftlint"
    echo "  or visit: https://github.com/realm/SwiftLint"
    exit 1
fi

# Run SwiftLint on all Swift files
RESULT=$(swiftlint lint --quiet)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "${GREEN}✅ SwiftLint passed! No violations found.${NC}"
else
    echo "${RED}❌ SwiftLint found violations:${NC}"
    echo "$RESULT"
    echo ""
    echo "${YELLOW}Please fix the above violations before committing.${NC}"
    echo "You can run \"swiftlint\" to see all violations"
    echo "or \"swiftlint --fix\" to automatically fix some violations."
    exit 1
fi

exit 0
EOF

# Make the hook executable
chmod +x "$PRE_COMMIT_HOOK"

echo "✅ Pre-commit hook installed successfully!"
echo "💡 The hook will now run SwiftLint before each commit."
echo "🔧 To bypass the hook (not recommended), use: git commit --no-verify"
echo ""
echo "🧪 Testing the hook..."
if ".git/hooks/pre-commit"; then
    echo "🎉 Setup complete! The pre-commit hook is working correctly."
else
    echo "❌ There was an issue with the pre-commit hook setup."
    exit 1
fi
