#!/bin/env zsh


#Install xcode tools
xcode-select --install

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


#Create a new SSH-Key for git
touch ~/.ssh/config

echo << EOF > ~/.ssh/config
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF



# generate a new ssh-keygen
ssh-keygen -t ed25519 -C "$EMAIL" -q -P ""

# Start SSH agent
eval "$(ssh-agent -s)"

#Add SSH key
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

#Copy public key to clipboard
pbcopy < ~/.ssh/id_ed25519.pub


## Apperance defaults ##

# Dock size
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize 65

#Minimize to app
defaults write com.apple.dock minimize-to-application -bool true

# Do not re-arrage spaces based on usage
defaults write com.apple.dock mru-spaces -bool false

#Tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true



#Finder show path bar
defaults write com.apple.finder ShowPathbar -bool true


#disable natural scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false


# Install apps
brew install --cask discord battle-net element iina mactex dotnet-sdk steam transmission visual-studio-code