#!/bin/zsh

set -euo pipefail
IFS=$'\n\t'

if [[ $# -ne 2 || -z $1 || -z $2 ]]; then
  print -u2 -- 'Usage: /bin/zsh install.sh EMAIL "FULL NAME"'
  exit 1
fi

EMAIL=$1
NAME=$2
SCRIPT_DIR=${0:A:h}
STEP="Checking requirements"
INSTALLER_TMP=""
typeset -a COMPLETED SKIPPED
COMPLETED=()
SKIPPED=()

summary() {
  print -- "Completed steps: ${#COMPLETED}"
  if (( ${#COMPLETED} )); then printf '  - %s\n' "${COMPLETED[@]}"; fi
  if (( ${#SKIPPED} )); then
    print -- "Skipped:"
    printf '  - %s\n' "${SKIPPED[@]}"
  fi
}

TRAPZERR() {
  local code=$?
  print -u2 -- "Setup stopped during: $STEP (exit $code)."
  summary >&2
  return "$code"
}

trap 'if [[ -n "$INSTALLER_TMP" ]]; then rm -rf -- "$INSTALLER_TMP"; fi' EXIT

run() {
  local code
  "$@" || {
    code=$?
    print -u2 -- "Command failed: ${(q)@}"
    return "$code"
  }
}

step() {
  STEP=$1
  print -- "\n==> $STEP"
}

skip() {
  SKIPPED+=("$1")
  print -- "Skipping: $1"
}

# Keep the previous version of any configuration file we replace.
backup() {
  if [[ -e $1 ]]; then
    local destination="$1.macbuttler-backup-$(date +%Y%m%d%H%M%S)-$$"
    run cp -p "$1" "$destination"
    print -- "Backup: $destination"
  fi
}

copy_config() {
  if [[ -f $2 ]] && cmp -s "$1" "$2"; then return 0; fi
  backup "$2"
  run cp "$1" "$2"
}

if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
  print -u2 -- "Run this script on an Apple Silicon Mac in a native ARM64 terminal."
  exit 1
fi
if (( EUID == 0 )); then
  print -u2 -- "Run as your normal macOS user, without sudo. The script requests sudo when needed."
  exit 1
fi
MACOS_VERSION=$(run sw_vers -productVersion)
MACOS_MAJOR=${MACOS_VERSION%%.*}
INSTALLER_TMP=$(run mktemp -d)
COMPLETED+=("Requirements checked (macOS $MACOS_VERSION)")

step "Installing macOS updates"
run sudo -v -p "Please enter sudo password: "
run sudo softwareupdate --install --all
COMPLETED+=("macOS update command completed")

step "Setting up Vim"
copy_config "$SCRIPT_DIR/.vimrc" "$HOME/.vimrc"
COMPLETED+=("Vim configuration")

step "Installing Homebrew"
if [[ ! -x /opt/homebrew/bin/brew ]]; then
  # System updates can outlast sudo's credential cache; refresh before the
  # noninteractive installer needs administrator access.
  run sudo -v -p "Please enter sudo password: "
  run curl --proto '=https' --tlsv1.2 -fsSL -o "$INSTALLER_TMP/homebrew.sh" https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  NONINTERACTIVE=1 run /bin/bash "$INSTALLER_TMP/homebrew.sh"
fi
BREW_ENV=$(run /opt/homebrew/bin/brew shellenv)
eval "$BREW_ENV"
BREW_EVAL='eval "$(/opt/homebrew/bin/brew shellenv)"'
run touch "$HOME/.zprofile"
if ! grep -Fqx "$BREW_EVAL" "$HOME/.zprofile"; then
  printf '\n# Homebrew\n%s\n' "$BREW_EVAL" >> "$HOME/.zprofile"
fi
COMPLETED+=("Homebrew and shell environment")

step "Installing Oh My Zsh"
ZSH_DIR=${ZSH:-${ZDOTDIR:-$HOME}/.oh-my-zsh}
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
if [[ ! -d "$ZSH_DIR" ]]; then
  run curl --proto '=https' --tlsv1.2 -fsSL -o "$INSTALLER_TMP/ohmyzsh.sh" https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
  ZSH="$ZSH_DIR" run /bin/sh "$INSTALLER_TMP/ohmyzsh.sh" --unattended --keep-zshrc
fi
# A custom theme keeps the upstream theme intact and gives the prefix its correct width.
if [[ -f "$ZSH_DIR/themes/robbyrussell.zsh-theme" && -f "$ZSHRC" ]] && grep -Eq '^ZSH_THEME="(robbyrussell|macbuttler)"$' "$ZSHRC"; then
  CUSTOM_THEME_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}/themes"
  run mkdir -p "$CUSTOM_THEME_DIR"
  cat > "$INSTALLER_TMP/macbuttler.zsh-theme" <<'THEME'
source "$ZSH/themes/robbyrussell.zsh-theme"
PROMPT="%n@%m $PROMPT"
THEME
  copy_config "$INSTALLER_TMP/macbuttler.zsh-theme" "$CUSTOM_THEME_DIR/macbuttler.zsh-theme"
  if grep -qx 'ZSH_THEME="robbyrussell"' "$ZSHRC"; then
    backup "$ZSHRC"
    run sed -i '' 's/^ZSH_THEME="robbyrussell"$/ZSH_THEME="macbuttler"/' "$ZSHRC"
  fi
else
  skip "Prompt customization (existing shell configuration or theme differs)"
fi
COMPLETED+=("Oh My Zsh")

step "Installing Rust"
if [[ ! -x "${CARGO_HOME:-$HOME/.cargo}/bin/rustup" ]]; then
  run curl --proto '=https' --tlsv1.2 -fsSL -o "$INSTALLER_TMP/rustup.sh" https://sh.rustup.rs
  run /bin/sh "$INSTALLER_TMP/rustup.sh" -y
fi
COMPLETED+=("Rust")

step "Configuring Git and SSH"
run git config --global user.name "$NAME"
run git config --global user.email "$EMAIL"
run mkdir -p "$HOME/.ssh"
run touch "$HOME/.ssh/config"
run chmod 700 "$HOME/.ssh"
run chmod 600 "$HOME/.ssh/config"
if ! grep -Eq '^[[:space:]]*Host[[:space:]]+github\.com([[:space:]]|$)' "$HOME/.ssh/config"; then
  cat >> "$HOME/.ssh/config" <<'SSH_CONFIG'

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
SSH_CONFIG
fi
NEW_SSH_KEY=0
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  run /usr/bin/ssh-keygen -t ed25519 -C "$EMAIL" -q -N "" -f "$HOME/.ssh/id_ed25519"
  NEW_SSH_KEY=1
fi
if [[ -z ${SSH_AUTH_SOCK:-} ]]; then
  SSH_AGENT_ENV=$(run /usr/bin/ssh-agent -s)
  eval "$SSH_AGENT_ENV"
fi
if (( NEW_SSH_KEY )); then
  run /usr/bin/ssh-add "$HOME/.ssh/id_ed25519"
else
  run /usr/bin/ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519"
fi
if [[ ! -f "$HOME/.ssh/id_ed25519.pub" ]]; then
  run /usr/bin/ssh-keygen -y -f "$HOME/.ssh/id_ed25519" > "$HOME/.ssh/id_ed25519.pub"
fi
run pbcopy < "$HOME/.ssh/id_ed25519.pub"
COMPLETED+=("Git and SSH (public key copied to clipboard)")

step "Installing apps"
if [[ -n ${SKIP_APPS:-} ]]; then
  run brew install --cask halloy
  skip "Apps and additional Homebrew tools except Halloy (SKIP_APPS is set)"
else
  # Intel-only apps need Rosetta even when the Mac itself is Apple Silicon.
  if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
    run sudo softwareupdate --install-rosetta --agree-to-license
  fi
  run brew install --cask battle-net chatgpt halloy onyx transmission discord iina rustdesk utm dolphin vcmi signal visual-studio-code dotnet-sdk mist steam zed appcleaner
  run brew install --cask mactex
  run brew install python3 swiftly
  if (( MACOS_MAJOR >= 26 )); then
    run brew install container
  else
    skip "container requires macOS 26 or newer (found $MACOS_VERSION)"
  fi
fi
COMPLETED+=("App installation")

step "Configuring desktop preferences"
run defaults write com.apple.dock largesize -int 70
run defaults write com.apple.dock tilesize -int 46
run defaults write com.apple.dock minimize-to-application -bool true
run defaults write com.apple.dock mru-spaces -bool false
run defaults write com.apple.AppleMultitouchTrackpad Clicking -int 1
run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -int 1
run defaults write com.apple.finder ShowPathbar -bool true
run defaults write com.apple.finder ShowStatusBar -bool true
run defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
run defaults write com.apple.Safari ShowFavoritesBar-v2 -bool true
run defaults write com.apple.Safari IncludeDevelopMenu -bool true
killall Dock || true
killall Finder || true
killall SystemUIServer || true
COMPLETED+=("Desktop preferences (some settings may require logout)")

step "Copying app configuration"
HALLOY_DIR="$HOME/Library/Application Support/halloy"
run mkdir -p "$HALLOY_DIR/themes"
copy_config "$SCRIPT_DIR/halloy/config.toml" "$HALLOY_DIR/config.toml"
copy_config "$SCRIPT_DIR/halloy/themes/midnight.toml" "$HALLOY_DIR/themes/midnight.toml"
WOG_DIR="$HOME/Library/Containers/com.2dboy.worldofgoo2mac/Data/Library/Application Support/WorldOfGoo2"
if [[ -d "$WOG_DIR" ]]; then
  copy_config "$SCRIPT_DIR/wog/wog2_1.dat" "$WOG_DIR/wog2_1.dat"
else
  skip "World of Goo 2 data: install and launch the game once, then rerun to copy it"
fi
COMPLETED+=("App configuration")

print -- "\nSetup finished."
summary
print -- "Add the copied SSH public key to your GitHub account if needed."
print -- "Open a new terminal to load your shell configuration."
print -- "If macOS updates require a restart, restart to finish applying them."
if [[ -z ${SKIP_APPS:-} ]]; then
  print -- "Swiftly is installed; run 'swiftly init' to set up a Swift toolchain."
fi

print -- "Done! ;)"
print -- "Your  Mac 🧑‍💻 is ready!"
