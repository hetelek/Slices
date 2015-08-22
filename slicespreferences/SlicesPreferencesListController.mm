#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

#import <Social/Social.h>

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

- (void)viewDidLoad
{
	[super viewDidLoad];

	// get bundle
	NSBundle *bundle = [NSBundle bundleForClass:[SlicesPreferencesListController class]];

	// add heart image
	UIImage *image = [UIImage imageNamed:@"heart" inBundle:bundle compatibleWithTraitCollection:nil];

	if (image)
	{
		UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStyleBordered target:self action:@selector(heartTapped:)];
		barButtonItem.tintColor = [UIColor redColor];
		self.navigationItem.rightBarButtonItem = barButtonItem;
	}
}

- (void)heartTapped:(id)sender
{
	SLComposeViewController *composeViewController;
	if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter])
		composeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
	else if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook])
		composeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
	else if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeSinaWeibo])
		composeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
	else if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTencentWeibo])
		composeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTencentWeibo];

	[composeViewController setInitialText:@"I use #Slices to manage multiple settings, accounts, and data bundles for apps!"];
	[composeViewController addURL:[NSURL URLWithString:@"http://cydia.saurik.com/package/org.thebigboss.slices/"]];
	
	[self presentViewController:composeViewController animated:YES completion:nil];
}

- (void)openTwitter:(id)arg1
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://twitter.com/hetelek"]];   
}
@end
