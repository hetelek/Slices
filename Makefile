#THEOS_DEVICE_IP = 192.168.1.17 #iphone6+
#THEOS_DEVICE_IP = 192.168.1.5 #iphone4s
#THEOS_DEVICE_IP = 192.168.1.6 #ipad
#THEOS_DEVICE_IP = 192.168.1.11 #ipod
#THEOS_DEVICE_IP = 129.21.138.139 #rit iphone6+

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222

TARGET := iphone:8.4:2.0
ARCHS := armv7 arm64
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include theos/makefiles/common.mk

TWEAK_NAME = Slices
Slices_FILES = Model/SSKeychain/SSKeychain.m Model/GameCenterAccountManager.mm Model/AppGroupSlicer.mm Model/Expetelek/Expetelek.mm Tweak.xm Model/RawSlicer.mm Model/Slicer.mm Model/FolderMigrator.mm Model/SliceSetting.mm
Slices_FRAMEWORKS = Security UIKit
Slices_PRIVATE_FRAMEWORKS = GameKit BackBoardServices
Slices_LIBRARIES = MobileGestalt applist

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += slicespreferences
SUBPROJECTS += slicesapp
include $(THEOS_MAKE_PATH)/aggregate.mk
