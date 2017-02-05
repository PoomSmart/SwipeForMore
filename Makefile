DEBUG = 0
TAGET = iphone:clang:latest
PACKAGE_VERSION = 1.1.6

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SwipeForMore
SwipeForMore_FILES = SwipeActionController.m Tweak.xm
SwipeForMore_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp -R Resources $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SwipeForMore$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)
