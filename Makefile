INSTALL_TARGET_PROCESSES = Messenger

# One source for the version: control. The probe compiles the same number into
# its report, so a build can always be identified from the log alone.
PACKAGE_VERSION = $(shell sed -n 's/^Version: //p' control)
ARCHS = arm64 arm64e

TWEAK_NAME = SNMessenger
$(TWEAK_NAME)_FILES = $(wildcard SNMessenger.xm Settings/*.mm)
$(TWEAK_NAME)_CCFLAGS = -std=c++17
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -DSN_PROBE_VERSION=\"$(PACKAGE_VERSION)\"
$(TWEAK_NAME)_EXTRA_FRAMEWORKS = Cephei

# The probe is off by default. It hooks -viewDidAppear: on every view
# controller, formats a string on per-row hot paths and rewrites its report
# file whenever anything moves — a cost worth paying while investigating and
# not worth paying all day. Build with DIAGNOSTICS=1 to get it back.
ifeq ($(DIAGNOSTICS), 1)
    $(TWEAK_NAME)_FILES += Diagnostics/SNDiagnostics.mm Diagnostics/SNSymbolScan.mm
    $(TWEAK_NAME)_CFLAGS += -DSN_DIAGNOSTICS=1
endif

ifeq ($(SIDELOAD), 1)
    $(TWEAK_NAME)_FILES += fishhook/fishhook.c SideloadedFixes.xm
    $(TWEAK_NAME)_CFLAGS += -DSIDELOAD=1
endif

ifeq ($(ROOTLESS), 1)
    THEOS_PACKAGE_SCHEME = rootless
    TARGET = iphone:clang:latest:15.0
else
    TARGET = iphone:clang:latest:12.4
endif

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += SNMessengerPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
