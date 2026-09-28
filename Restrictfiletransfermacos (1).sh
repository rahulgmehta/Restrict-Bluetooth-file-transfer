#!/zsh
# Zsh script to disable Bluetooth File Sharing on macOS while keeping standard Bluetooth functional (Audio, HID, etc.)
# Run as: root / SYSTEM / MDM Agent

# 1. Determine active user context
CURRENT_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

if [ -z "$CURRENT_USER" ]; then
    echo "No logged-in user detected. Exiting..."
    exit 1
fi

USER_ID=$(id -u "$CURRENT_USER")

# Target policy setting: PrefKeyServicesEnabled = false (0)
# Check current compliance status for the logged-in user
CURRENT_STATUS=$(launchctl asuser "$USER_ID" sudo -u "$CURRENT_USER" defaults -currentHost read com.apple.Bluetooth PrefKeyServicesEnabled 2>/dev/null)

if [ "$CURRENT_STATUS" = "0" ]; baseline="Compliant"
    COMPLIANCE="Compliant"
else
    COMPLIANCE="Non-compliant"
fi

echo "Current Logged-in User: $CURRENT_USER"
echo "Bluetooth File Sharing Status: $CURRENT_STATUS (0 = Disabled, 1 = Enabled)"
echo "Compliance Status: $COMPLIANCE"

# Remediation block
if [ "$COMPLIANCE" = "Non-compliant" ]; then
    echo "Applying Bluetooth file transfer restriction..."

    # Apply preference change for current host under the active user's session
    launchctl asuser "$USER_ID" sudo -u "$CURRENT_USER" defaults -currentHost write com.apple.Bluetooth PrefKeyServicesEnabled -bool false

    # Enforce global disablement across global preference domains (macOS Big Sur, Monterey, Ventura, Sonoma, Sequoia)
    defaults write /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled -bool false

    # Terminate the OBEX Sharing Daemon to apply changes immediately without a reboot
    killall OBEXAgent 2>/dev/null

    # Double check compliance
    VERIFY_STATUS=$(launchctl asuser "$USER_ID" sudo -u "$CURRENT_USER" defaults -currentHost read com.apple.Bluetooth PrefKeyServicesEnabled 2>/dev/null)

    if [ "$VERIFY_STATUS" = "0" ]; then
        echo "Remediation successfully verified. Bluetooth File Sharing is disabled."
    else
        echo "Error: Remediation failed. File transfer restriction could not be applied."
        exit 1
    fi
else
    echo "Bluetooth file transfer is already restricted."
fi

exit 0