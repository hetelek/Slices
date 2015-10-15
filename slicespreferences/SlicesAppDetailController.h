#import <substrate.h>

#import <UIKit/UIKit.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSEditableListController.h>
#import <Preferences/PSListItemsController.h>

#import "SliceDetailController.h"

#import "../Model/Slicer.h"
#import "../Headers/LocalizationKeys.h"

@interface SlicesAppDetailController : PSEditableListController
{
	PSSpecifier *_specifierToRename;
}

@end
