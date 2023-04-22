# MacButtler
small macOS script installing basic macOS apps to get you up and running on your fresh installation

## Usage
To use MacButtler just replace the placeholders form this command with your actual information:

```zsh
MAC_BUTTLER_TMP=$(mktemp -d) curl -L --output $MAC_BUTTLER_TMP/mac_buttler.zip https://github.com/stoiandan/MacButtler/archive/refs/heads/main.zip && unzip $MAC_BUTTLER_TMP/mac_buttler.zip && chmod +x $MAC_BUTTLER_TMP/MacButtler-main/install.sh && $MAC_BUTTLER_TMP/MacButtler-main/install.sh EMAIL "FULL NAME"
```
