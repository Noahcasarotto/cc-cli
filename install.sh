#!/bin/bash

# CC CLI Installer
# This script installs the CC CLI tool

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/usr/local/bin"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    INSTALL_DIR="/usr/local/bin"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    INSTALL_DIR="/usr/local/bin"
fi

echo -e "${BLUE}"
echo "   _____  _____ "
echo "  / ____|/ ____|"
echo " | |    | |     "
echo " | |    | |     "
echo " | |____| |____ "
echo "  \_____|\_____| "
echo -e "${CYAN}Installer${NC}"
echo

# Make the script executable
chmod +x cc.sh

# Check if running with sudo
if [ "$(id -u)" != "0" ]; then
    echo -e "${YELLOW}Installing CC CLI to $HOME/bin (no sudo)${NC}"
    INSTALL_DIR="$HOME/bin"
    
    # Create directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
    fi
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo -e "${YELLOW}Adding $INSTALL_DIR to your PATH in ~/.bashrc or ~/.zshrc${NC}"
        
        # Determine shell config file
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_CONFIG="$HOME/.zshrc"
        else
            SHELL_CONFIG="$HOME/.bashrc"
        fi
        
        echo "# Added by CC CLI installer" >> "$SHELL_CONFIG"
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_CONFIG"
        echo -e "${YELLOW}Please restart your terminal or run 'source $SHELL_CONFIG' after installation.${NC}"
    fi
else
    echo -e "${YELLOW}Installing CC CLI to $INSTALL_DIR (with sudo)${NC}"
fi

# Copy script to installation directory
cp cc.sh "$INSTALL_DIR/cc"

# Make executable
chmod +x "$INSTALL_DIR/cc"

echo -e "${GREEN}CC CLI has been installed successfully!${NC}"
echo
echo -e "You can now use CC CLI by running: ${CYAN}cc${NC}"
echo
echo -e "To get started, try one of these commands:"
echo -e "  ${CYAN}cc help${NC}                 # Show help"
echo -e "  ${CYAN}cc install${NC}              # Install Ollama and download the default model"
echo -e "  ${CYAN}cc run \"Hello, CC!\"${NC} # Run CC with a prompt"
echo

# Offer to install dependencies now
read -p "Would you like to install Ollama and download the default CC model now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing Ollama and downloading the default CC model...${NC}"
    "$INSTALL_DIR/cc" install
    echo -e "${GREEN}Installation complete!${NC}"
    echo -e "${YELLOW}You can now use CC by running:${NC} ${CYAN}cc run${NC}"
else
    echo -e "${YELLOW}You can install Ollama and download CC models later by running:${NC} ${CYAN}cc install${NC}"
fi

exit 0 