#!/bin/zsh

#check root access for homebrew


if [ "$#" -ne 2 ] 
then
  echo "Please provide your e-mail and Name"
  echo "install.sh tim@apple.com \"Tim Apple\" "
  exit 1
fi


EMAIL=$1
NAME=$2

echo "Setting up environment with email $EMAIL and with name: $NAME"

#update macOS
echo "Installing macOS updateds..."
softwareupdate -i

# Copy .vimrc file
# This file contains a custom setup to enable higlight in search, line numbering
# and other features of vim 
echo "Setting up vim..."

cp ${0:a:h}/.vimrc ~/.vimrc

# Install Homebrew and Command Line Tools 
echo "Installing Homebrew"

sudo -v -p "Please enter sudo password:"

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &

PID=$!

wait $PID

# Finish installing Homebrew
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"


# Install Oh-My-Zsh
echo "Installing Oh-My-Zsh"

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &

PID=$!

wait $PID

# Edit default theme to reflect username@machine_name in terminal prompt
sed -i -e '/^PROMPT=.*/s/➜/%n@%m ➜/g' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme


## configure git
echo "Configureing git..."
git config --global user.name "$NAME"
git config --global user.email "$EMAIL"

#Create a new SSH-Key for git
echo "Setting up SSH keys"
mkdir ~/.ssh
touch ~/.ssh/config


cat << EOF > ~/.ssh/config
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF



# generate a new ssh-keygen
ssh-keygen -t ed25519 -C "$EMAIL" -q -P "" -f ~/.ssh/id_ed25519

# Start SSH agent
eval "$(ssh-agent -s)"

#Add SSH key
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

#Copy public key to clipboard
pbcopy < ~/.ssh/id_ed25519.pub


## Apperance defaults ##
echo "Configuring Desktop settings"
# Dock size
defaults write com.apple.dock "largesize" -int "78" && killall Dock
defaults write com.apple.dock "tilesize" -int "55" && killall Dock

#Minimize to app
defaults write com.apple.dock "minimize-to-application" -bool "true" && killall Dock

# Do not re-arrage spaces based on usage
defaults write com.apple.dock "mru-spaces" -bool "true" && killall Dock

#Tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true



#Finder show path bar
defaults write com.apple.finder "ShowPathba"r -bool "true" && killall Dock


#disable natural scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool "false" && killall Dock


# Install apps
echo "Installing apps from homebrew..."

sudo -v -p "Please enter sudo password:"


brew install --cask battle-net halloy onyx transmission discord	iina rustdesk	utm dolphin mactex signal visual-studio-code dotnet-sdk mist steam zed && brew install python3

PID=$!

wait $PID


echo "Restarting dock"
killall Dock


##Setup Finder

#Show status bar
defaults write com.apple.Finder ShowStatusBar -bool true

#Show status bar
defaults write com.apple.Finder ShowStatusbar -bool true


echo "Restarting Finder"
killall Finder


##Safari

#show bookmarks
defaults write com.apple.Safari ShowFavoritesBar -bool true

#enable developer
defaults write com.apple.Safari IncludeDevelopMenu -bool true





echo "Done! ;)"
echo "Your  Mac 🧑‍💻 is ready!"
