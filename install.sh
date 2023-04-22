#!/bin/zsh

if [ "$#" -ne 2 ] then
  echo "Please provide your e-mail and Name"
  echo "install.sh tim@apple.com \"Tim Apple\" "
  exit 1
fi


EMAIL=$1
NAME=$2

echo "Setting up environment with email $EMAIL and with name: $NAME"

#update macOS
softwareupdate -i

#Install xcode tools
xcode-select --install &> /dev/null

until $(xcode-select -p &> /dev/null); do
    sleep 5;
done

# Copy .vimrc file
# This file contains a custom setup to enable higlight in search, line numbering
# and other features of vim 
echo "Setting up vim..."
cp .vimrc ~/.vimrc 


# Install Homebrew and Command Line Tools 
echo "Installing Homebrew"
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


# Finish installing Homebrew
echo '# Set PATH, MANPATH, etc., for Homebrew.' >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellevn)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellevn)"


# Install Oh-My-Zsh
echo "Installing Oh-My-Zsh"

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Edit default theme to reflect username@machine_name in terminal prompt
sed 's/➜ :%/%n@%m ➜ :%/' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme > !$


## configure git
echo "Configureing git..."
git config --global user.name "$NAME"
git config --global user.email "$EMAIL"

#Create a new SSH-Key for git
echo "Setting up SSH keys"
mkdir -p ~/.ssh
touch ~/.ssh/config

echo << EOF > ~/.ssh/config
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF



# generate a new ssh-keygen
ssh-keygen -t ed25519 -C "$EMAIL" -q -P "" -f id_ed25519

# Start SSH agent
eval "$(ssh-agent -s)"

#Add SSH key
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

#Copy public key to clipboard
pbcopy < ~/.ssh/id_ed25519.pub


## Apperance defaults ##
echo "Configuring Desktop settings"
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
echo "Installing apps from homebrew..."
brew install --cask discord battle-net element iina mactex dotnet-sdk steam transmission visual-studio-code



echo "Done!"