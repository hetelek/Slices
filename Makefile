THEOS_DEVICE_IP = 192.168.1.17 #iphone6+
#THEOS_DEVICE_IP = 192.168.1.5 #iphone4s
#THEOS_DEVICE_IP = 192.168.1.6 #ipad
#THEOS_DEVICE_IP = 192.168.1.11 #ipod

TARGET := iphone:8.1:2.0
ARCHS := armv7 arm64
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include theos/makefiles/common.mk

TWEAK_NAME = Slices
Slices_FILES = Expetelek/Expetelek.mm Tweak.xm Slicer.xm
Slices_FRAMEWORKS = UIKit
Slices_PRIVATE_FRAMEWORKS = BackBoardServices
Slices_LIBRARIES = MobileGestalt applist

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += slicespreferences
include $(THEOS_MAKE_PATH)/aggregate.mk
