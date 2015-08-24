TARGET := iphone:8.4:2.0
ARCHS := armv7 arm64
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include theos/makefiles/common.mk

APPLICATION_NAME = SlicesApp
SlicesApp_FILES = main.m AppDelegate.m ViewController.m
SlicesApp_FRAMEWORKS = UIKit CoreGraphics Braintree

include $(THEOS_MAKE_PATH)/application.mk
