# MacButtler
small macOS script installing basic macOS apps to get you up and running on your fresh installation

## Usage
To use MacButtler just replace the placeholders form this command with your actual information:

```zsh
MAC_BUTTLER_TMP=$(mktemp -d) && cd $MAC_BUTTLER_TMP && curl -L --output mac_buttler.zip https://github.com/stoiandan/MacButtler/archive/refs/heads/main.zip && unzip mac_buttler.zip && chmod +x MacButtler-main/install.sh && MacButtler-main/install.sh EMAIL "FULL NAME"
```
