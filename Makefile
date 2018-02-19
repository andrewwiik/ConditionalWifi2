SHARED_CFLAGS = -fobjc-arc
CFLAGS = -fobjc-arc
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ConditionalWiFi2
ConditionalWiFi2_FILES = Tweak.xm
ConditionalWiFi2_FRAMEWORKS = UIKit Foundation SystemConfiguration CoreFoundation
ConditionalWiFi2_LDFLAGS += ./Preferences.tbd ./SpringBoardServices.tbd

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Preferences"
