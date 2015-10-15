#import <substrate.h>

#import <UIKit/UIKit.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSTextFieldSpecifier.h>
#import <Preferences/PSListItemsController.h>

#import "SlicesEditableTableCell.h"

#import "../Model/Slicer.h"
#import "../Model/GameCenterAccountManager.h"
#import "../Headers/LocalizationKeys.h"

extern NSString* const PSKeyNameKey;
extern NSString* const PSIsRadioGroupKey;
extern NSString* const PSCellClassKey;
extern NSString* const PSRadioGroupCheckedSpecifierKey;
extern NSString* const PSActionKey;

#define NAME_SPECIFIER_IDENTIFIER @"name"

@interface SliceDetailController : PSListController
@end
