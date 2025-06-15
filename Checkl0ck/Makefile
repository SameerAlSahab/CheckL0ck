ARCHS = arm64
TARGET = iphone:clang:14.0:16.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Checkl0ck
Checkl0ck_FILES = Tweak.xm Checkl0ckManager.m
Checkl0ck_FRAMEWORKS = LocalAuthentication
Checkl0ck_PRIVATE_FRAMEWORKS = SpringBoardFoundation
Checkl0ck_CFLAGS = -fobjc-arc

BUNDLE_NAME = Checkl0ckPrefs
Checkl0ckPrefs_FILES = Preferences/Checkl0ckPrefsController.m
Checkl0ckPrefs_INSTALL_PATH = /Library/PreferenceBundles
Checkl0ckPrefs_FRAMEWORKS = UIKit
Checkl0ckPrefs_PRIVATE_FRAMEWORKS = Preferences
Checkl0ckPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk 