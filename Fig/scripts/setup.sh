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

# Install Homebrew dependencies
echo "Installing Homebrew dependencies..."
brew bundle install --file="$(dirname "$0")/../Brewfile"

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
echo "You can now:"
echo "  - Build: swift build"
echo "  - Test: swift test"
echo "  - Format: swiftformat ."
echo "  - Lint: swiftlint lint"
