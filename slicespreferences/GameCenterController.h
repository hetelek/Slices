#import <Preferences/PSSpecifier.h>
#import <Preferences/PSEditableListController.h>
#import <Preferences/PSTextFieldSpecifier.h>
#import <Preferences/PSEditableTableCell.h>

#import "SlicesEditableTableCell.h"

#import "../Model/GameCenterAccountManager.h"
#import "../Headers/LocalizationKeys.h"

extern NSString* const PSDeletionActionKey;
extern NSString* const PSKeyNameKey;
extern NSString* const PSCellClassKey;
extern NSString* const PSEnabledKey;

#define ADD_ACCOUNT_SPECIFIER_IDENTIFIER @"addAccount"

@interface GameCenterController : PSEditableListController
@end