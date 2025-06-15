#!/bin/bash

PLIST="/var/mobile/Library/Preferences/com.yourcompany.checkl0ck.plist"

if [ -f "$PLIST" ]; then
    echo "[+] Checkl0ck preferences found."
else
    echo "[-] Checkl0ck preferences not found."
fi

echo -n "[+] Jailbreak state: "
if [ -f "/bin/bash" ]; then
    echo "Jailbroken"
else
    echo "Not jailbroken"
fi

if [ -f "$PLIST" ]; then
    PASSCODE=$(defaults read $PLIST isPasscodeEnabled 2>/dev/null)
    BIOMETRIC=$(defaults read $PLIST biometricsEnabled 2>/dev/null)
    echo "[+] Passcode enabled: $PASSCODE"
    echo "[+] Biometrics enabled: $BIOMETRIC"
else
    echo "[-] Cannot read tweak status."
fi 