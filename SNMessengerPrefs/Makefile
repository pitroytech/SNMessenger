ifeq ($(ROOTLESS), 1)
    THEOS_PACKAGE_SCHEME = rootless
    TARGET = iphone:clang:latest:15.0
else
    TARGET = iphone:clang:latest:12.4
endif

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SNMessengerPrefs
SNMessengerPrefs_FILES = SNRootListController.m
SNMessengerPrefs_FRAMEWORKS = UIKit
SNMessengerPrefs_PRIVATE_FRAMEWORKS = Preferences MobileCoreServices
SNMessengerPrefs_EXTRA_FRAMEWORKS = Cephei
SNMessengerPrefs_INSTALL_PATH = /Library/PreferenceBundles
SNMessengerPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
