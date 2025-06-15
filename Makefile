ARCHS = arm64 arm64e
TARGET = rootless
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ChecklC
ChecklC_FILES = Tweak.xm ChecklCManager.m ChecklCPasscodeViewController.m
ChecklC_FRAMEWORKS = UIKit LocalAuthentication
ChecklC_CFLAGS = -fobjc-arc

BUNDLE_NAME = ChecklCPrefs
ChecklCPrefs_FILES = layout/Library/PreferenceBundles/ChecklCPrefsController.m
ChecklCPrefs_INSTALL_PATH = /Library/PreferenceBundles
ChecklCPrefs_FRAMEWORKS = UIKit
ChecklCPrefs_PRIVATE_FRAMEWORKS = Preferences
ChecklCPrefs_CFLAGS = -fobjc-arc
ChecklCPrefs_LIBRARIES = rocketbootstrap

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk 