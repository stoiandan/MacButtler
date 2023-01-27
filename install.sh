#!/bin/env zsh


# Copy .vimrc file
# This file contains a custom setup to enable higlight in search, line numbering
# and other features of vim 
cp .vimrc ~/.vimrc 


# Install HomeBrew and Command Line Tools 
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


# Finish installing Homebrew
echo '# Set PATH, MANPATH, etc., for Homebrew.' >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellevn)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellevn)"


# Install Oh-My-Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Edit default theme to reflect username@machine_name in terminal prompt
sed 's/➜ :%/%n@%m ➜ :%/' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme > !$