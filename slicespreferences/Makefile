TARGET := iphone:8.1:2.0
ARCHS := armv7 arm64
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include theos/makefiles/common.mk

BUNDLE_NAME = SlicesPreferences
SlicesPreferences_FILES = ../Model/RawSlicer.mm ../Model/Slicer.mm ../Model/FolderMigrator.mm ../Model/SliceSetting.mm SlicesPreferences.mm SlicesAppController.mm SlicesAppDetailController.mm
SlicesPreferences_INSTALL_PATH = /Library/PreferenceBundles
SlicesPreferences_FRAMEWORKS = UIKit
SlicesPreferences_PRIVATE_FRAMEWORKS = Preferences BackBoardServices
SlicesPreferences_LIBRARIES = applist

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SlicesPreferences.plist$(ECHO_END)
