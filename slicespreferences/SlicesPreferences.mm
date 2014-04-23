#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

#import <AppList/AppList.h>

@interface SlicesPreferencesListController : PSListController
@end

static NSString *settingsPath = @"/var/mobile/Library/Preferences/com.expetelek.slicespreferences.plist";

@implementation SlicesPreferencesListController
- (id)specifiers
{
	if(_specifiers == nil)
		_specifiers = [self loadSpecifiersFromPlistName:@"SlicesPreferences" target:self];	

	return _specifiers;
}

- (void)openTwitter:(id)arg1
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://twitter.com/hetelek"]];   
}
@end
