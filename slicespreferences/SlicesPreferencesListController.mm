#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

#import <AppList/AppList.h>

#import "../Model/GameCenterAccountManager.h"
#import "../Headers/LocalizationKeys.h"

@interface SlicesPreferencesListController : PSListController
@end

@implementation SlicesPreferencesListController
- (id)specifiers
{
	if(_specifiers == nil)
	{
		_specifiers = [self loadSpecifiersFromPlistName:@"SlicesPreferences" target:self];

		// localize all the strings
		NSBundle *bundle = [NSBundle bundleWithPath:@"/Library/Application Support/Slices/Slices.bundle"];
		for (PSSpecifier *specifier in _specifiers)
		{
			NSString *footerTextValue = [specifier propertyForKey:@"footerText"];
			if (footerTextValue)
				[specifier setProperty:Localize(footerTextValue) forKey:@"footerText"];

			NSString *name = specifier.name; // "label" key in plist
			if (name)
				specifier.name = Localize(name);
		}
	}

	return _specifiers;
}

- (void)openTwitter:(id)arg1
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://twitter.com/hetelek"]];   
}
@end
