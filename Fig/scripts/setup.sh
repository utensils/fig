#!/bin/bash
# setup.sh
# Development environment setup script for Fig

set -e

echo "Setting up Fig development environment..."
echo ""

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is required but not installed."
    echo "Install it from: https://brew.sh"
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIG_DIR="$(dirname "$SCRIPT_DIR")"

# Install Homebrew dependencies
echo "Installing Homebrew dependencies..."
brew bundle install --file="$FIG_DIR/Brewfile"

# Change to Fig directory for remaining commands
cd "$FIG_DIR"

# Install git hooks
echo ""
echo "Installing git hooks..."
lefthook install

# Resolve Swift package dependencies
echo ""
echo "Resolving Swift package dependencies..."
swift package resolve

echo ""
echo "Setup complete!"
echo ""
echo "From the Fig directory, you can now:"
echo "  - Build: swift build"
echo "  - Test: swift test"
echo "  - Format: swiftformat ."
echo "  - Lint: swiftlint lint"
