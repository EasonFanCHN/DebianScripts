#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Ensure the script is run as a normal user, not root
if [ "$(id -u)" -eq 0 ]; then
    echo "Please run this script as a normal user, not root."
    exit 1
fi

# Ensure Vim is installed
sudo apt update -qq && sudo apt install -y vim

# Fix arrow key issue in Vim
VIMRC="$HOME/.vimrc"
if ! grep -q "set nocompatible" "$VIMRC"; then
    echo "set nocompatible" >>"$VIMRC"
fi
if ! grep -q "set backspace=indent,eol,start" "$VIMRC"; then
    echo "set backspace=indent,eol,start" >>"$VIMRC"
fi

echo "Vi/Vim arrow key issue fixed. Restart your terminal or reload Vim for changes to take effect."
