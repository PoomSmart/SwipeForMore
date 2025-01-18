TAGET = iphone:clang:latest:8.0
ARCHS = armv7 arm64
PACKAGE_VERSION = 1.2.5
INSTALL_TARGET_PROCESSES = Cydia

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SwipeForMore
$(TWEAK_NAME)_FILES = SwipeActionController.m Tweak.xm
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
