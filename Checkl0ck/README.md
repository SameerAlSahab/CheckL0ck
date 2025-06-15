# Checkl0ck

A jailbreak tweak to re-enable passcode and biometrics on A11 (iPhone 8/X) checkm8 jailbreaks.

## Features
- Native passcode and biometric unlock
- FaceID/TouchID support in apps
- Secure notification previews
- Jailbreak state detection
- Preferences bundle

## Installation
1. Build with Theos: `make package`
2. Install `.deb` via Sileo/Zebra or `dpkg -i`

## Usage
- Enable/disable in Settings > Checkl0ck
- View jailbreak and biometric status

## Testing
Run the helper script:
```sh
bash test_checkl0ck.sh
```

## Limitations
- Only works on jailbroken A11 devices
- No Apple Pay support 