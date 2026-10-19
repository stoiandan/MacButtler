# MacButtler
Set up apps, developer tools, and personal preferences on a fresh Apple Silicon Mac.

## Requirements

- Run from a native Apple Silicon terminal as your normal administrator user, without prefixing the script with `sudo`.
- An internet connection and your administrator password are required.
- `container` is installed on macOS 26 or newer; it is skipped on older versions.
- To copy the bundled World of Goo 2 data, install and launch the game once before running the script. Otherwise, that copy is skipped with a reminder.

## Usage
Paste this block into Terminal, replacing `EMAIL` and `FULL NAME` with your information:

```zsh
(
  MAC_BUTTLER_TMP=$(mktemp -d) &&
  cd "$MAC_BUTTLER_TMP" &&
  curl -fsSL -o mac_buttler.zip https://github.com/stoiandan/MacButtler/archive/refs/heads/main.zip &&
  unzip -q mac_buttler.zip &&
  /bin/zsh MacButtler-main/install.sh EMAIL "FULL NAME"
)
```

Zsh runs the script directly, so `chmod` is unnecessary. The parentheses keep your terminal in its original directory when the script finishes. A failed download or extraction stops the remaining commands.

The command downloads the current GitHub `main` branch. Local edits must be pushed there before this command will use them.

## What to expect

The script runs macOS updates, installs Homebrew, Oh My Zsh, Rust, and the selected apps, configures Git and SSH, and applies desktop preferences. It installs Rosetta if needed for Battle.net and Steam, accepting Apple's Rosetta license through `--agree-to-license`.

Installers run in sequence, and download errors stop setup. Errors identify the current step and failed command; a summary lists completed and skipped steps. Existing Homebrew, Oh My Zsh, and Rust installations are reused. Changed Vim, shell-theme, Halloy, and game-data files receive adjacent `.macbuttler-backup-*` copies before replacement.

The SSH key is created without a passphrase if `~/.ssh/id_ed25519` does not exist. Its public key is copied to the clipboard; add it to your GitHub account yourself if needed. Halloy uses the nickname and channels in the bundled `halloy/config.toml`; review these for your account.

After setup, open a new terminal. Run `swiftly init` if you want Swiftly to install and configure a Swift toolchain. Restart if requested by macOS updates; some preferences may need a logout, and preference support can vary by macOS version.

## Skip most apps
To skip most app installations, use the same block with this final command:

```zsh
SKIP_APPS=1 /bin/zsh MacButtler-main/install.sh EMAIL "FULL NAME"
```

This still installs Halloy and runs the system updates, developer tool installers, and configuration steps. It is not a dry run.

## Validation

Run the isolated installer checks from this repository:

```zsh
python3 -m unittest discover -s tests -v
```

These checks mock system commands and installers, and use temporary files. They cover fresh setup, reruns, missing game data, backups, Rosetta, older macOS versions, and download or installation failures. They do not replace testing on a clean macOS installation.
