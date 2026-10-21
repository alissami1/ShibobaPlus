TARGET := iphone:clang:latest:16.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Instagram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ShibobaPlus
ShibobaPlus_FILES = Tweak.xm
ShibobaPlus_FRAMEWORKS = UIKit Foundation UserNotifications
ShibobaPlus_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
