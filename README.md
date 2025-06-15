# ChecklC (Rootless Checkl0ck Clone)

A full-featured, rootless-compatible passcode and biometric lock tweak for iOS 15–16, inspired by Checkl0ck.

## Features
- Custom passcode UI overlay (Face ID/Touch ID support)
- Secure Keychain storage (kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
- Exponential lockout after failed attempts
- Blocks Control Center, Spotlight, Camera, and notifications while locked
- Preferences pane (RocketBootstrap):
  - Enable/disable ChecklC
  - Enable/disable biometrics
  - Enable/disable haptic feedback
  - Enable/disable diagnostics logging
  - Reset passcode
  - Disable lock (remove passcode, with confirmation)
- Diagnostics logging (syslog and optional file)
- Full localization and accessibility support
- Works on Dopamine, palera1n-rootless, and all iOS 15–16 devices

## Rootless Setup
- All binaries/resources are installed under `/var/jb/` (except `/Library/PreferenceBundles` for settings bundle)
- Requires RocketBootstrap and Preferenceloader (rootless)
- Sileo depiction and postinst included

## Installation
1. Build with Theos (TARGET=rootless)
2. Install .deb via Sileo or `dpkg -i`
3. Preferences appear in Settings > ChecklC
4. Toggle features and set passcode as desired

## Security
- All passcodes stored securely in Keychain
- Biometric and lockout logic matches original Checkl0ck
- All hooks are modular, ARC-safe, and rootless-compatible

---
For support or issues, open an issue on the repo or contact the maintainer. 