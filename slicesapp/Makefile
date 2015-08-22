TARGET := iphone:8.1:2.0
ARCHS := armv7 arm64
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include theos/makefiles/common.mk

APPLICATION_NAME = SlicesApp
SlicesApp_FILES = main.m SlicesAppApplication.mm RootViewController.mm
SlicesApp_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/application.mk
