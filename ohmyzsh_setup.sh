#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Ensure the script is run as a normal user, not root
if [ "$(id -u)" -eq 0 ]; then
    echo "Please run this script as a normal user, not root."
    exit 1
fi

# Install dependencies
sudo apt update && sudo apt install -y zsh curl git

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
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# Install zsh-syntax-highlighting plugin
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting plugin..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Change the default shell to Zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to Zsh..."
    chsh -s "$(which zsh)"
fi

echo "Oh My Zsh installation completed! Restart your terminal or log out and back in for changes to take effect."
