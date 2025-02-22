#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Ensure the script is run as a normal user, not root
if [ "$(id -u)" -eq 0 ]; then
    echo "Please run this script as a normal user, not root."
    exit 1
fi

# Detect OS and install dependencies accordingly
OS="$(uname)"
if [ "$OS" == "Linux" ]; then
    echo "Detected Linux system. Installing dependencies..."
    sudo apt update -qq && sudo apt install -y zsh curl git
elif [ "$OS" == "Darwin" ]; then
    echo "Detected macOS. Installing dependencies..."
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Please install Homebrew first: https://brew.sh/"
        exit 1
    fi
    brew install zsh curl git
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
else
    echo "Oh My Zsh is already installed."
fi

# Set Oh My Zsh theme to geoffgarside
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="geoffgarside"/' "$HOME/.zshrc"

# Install zsh-autosuggestions plugin
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions plugin..."
    git clone --quiet https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# Install zsh-syntax-highlighting plugin
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting plugin..."
    git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Export Path
sed -i 's/^# export PATH=.*/export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH/' "$HOME/.zshrc"
echo "export PATH=$PATH:/usr/sbin" | tee -a "$HOME/.zshrc"

# Enable plugins in .zshrc
sed -i 's/^plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

# Change the default shell to Zsh
sudo sed -i 's/^auth       required   pam_shells.so.*/# auth       required   pam_shells.so/' /etc/pam.d/chsh

if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to Zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
fi

echo "Oh My Zsh installation completed! Restart your terminal or log out and back in for changes to take effect."
