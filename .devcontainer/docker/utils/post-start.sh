#!/usr/bin/env bash

set -e

$LOGGER "Running post-start script..."

# Display welcome message
clear
printf "\033[0;32mStarter Project Dev Container: %s\033[0m\n\n" "$(basename "$PWD")"

# Display installed tools and versions
echo "=== Installed Tools ==="
echo "Bash: $(bash --version | head -n 1)"
echo "Git: $(git --version)"
echo "Homebrew: $(brew --version | head -n 1)"
echo "Python: $(python3 --version)"
# echo "Node.js: $(node --version)"
# echo "npm: $(npm --version)"
# echo "Pre-commit: $(pre-commit --version)"
echo ""

# Display environment information
echo "=== Environment Information ==="
echo "Hostname: $(hostname)"
echo "Working Directory: $(pwd)"
echo "User: $(whoami)"
echo ""

# Display container information if available
if command -v devcontainer-info &> /dev/null; then
    devcontainer-info
fi
