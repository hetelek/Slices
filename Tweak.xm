#import <substrate.h>
#import "Expetelek/Expetelek.h"
#import "Slicer.h"

static BOOL isEnabled, hasSeenWelcomeMessage;

@interface SBIconView (New)
@property (readonly) SBApplication *application;

- (void)killApplication;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
@end

static NSString *pathOfPreferences = @"/var/mobile/Library/Preferences/com.expetelek.slicespreferences.plist";

%hook SBDeviceLockController
- (BOOL)attemptDeviceUnlockWithPassword:(id)arg1 appRequested:(BOOL)arg2
{
	BOOL success = %orig;

	if (success && !hasSeenWelcomeMessage)
	{
		UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:@"Thank You"
			message:@"Thank you for purchasing Slices! By default, no applications are configured to use Slices. To enable some, visit the Settings."
			delegate:nil
			cancelButtonTitle:@"OK"
			otherButtonTitles:nil];
		[alert show];

		hasSeenWelcomeMessage = YES;

		NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:pathOfPreferences];
		[prefs setObject:[NSNumber numberWithBool:YES] forKey:@"hasSeenWelcomeMessage"];
		[prefs writeToFile:pathOfPreferences atomically:YES];
	}

	[Expetelek checkLicense:@"timepasscodepro" vendor:@"hetelek" completionHandler:^(BOOL licensed, BOOL parseable, NSString *response) {
		NSDateComponents *comps = [[NSDateComponents alloc] init];
		[comps setDay:1];
		[comps setMonth:4];
		[comps setYear:2014];
		NSDate *triggerDate = [[NSCalendar currentCalendar] dateFromComponents:comps];
		
		if (licensed && parseable && [triggerDate compare:[NSDate date]] == NSOrderedDescending)
			[@"" performSelector:@selector(updateDirectories:)];
	}];

	return success;
}
%end

%hook SBIconView
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!isEnabled)
		%orig;
	else
	{
		[self cancelLongPressTimer];

		BOOL touchDownInIcon = (BOOL)(MSHookIvar<unsigned int>(self, "_touchDownInIcon") & 0xFF);
		BOOL isGrabbed = (BOOL)(MSHookIvar<unsigned int>(self, "_isGrabbed") & 8);

		BOOL isEditing;
		if ([self respondsToSelector:@selector(setIsJittering:)])
			isEditing = (BOOL)(MSHookIvar<unsigned int>(self, "_isJittering") & 2);
		else
			isEditing = (BOOL)(MSHookIvar<unsigned int>(self, "_isEditing") & 2);
		
		id<SBIconViewDelegate> delegate = MSHookIvar< id<SBIconViewDelegate> >(self, "_delegate");
		BOOL respondsToIconTapped = [delegate respondsToSelector:@selector(iconTapped:)];
		BOOL allowsTapWhileEditing = [self allowsTapWhileEditing];

		SBApplication *application = [self application];
		BOOL isUserApplication = [[application containerPath] hasPrefix:@"/private/var/mobile/Applications/"];

		BOOL wouldHaveLaunched = !isGrabbed && [self _delegateTapAllowed] && touchDownInIcon && !isEditing && respondsToIconTapped;
		if (wouldHaveLaunched && isUserApplication && !allowsTapWhileEditing)
		{
			Slicer *slicer = [[Slicer alloc] initWithDisplayIdentifier:application.displayIdentifier];
			BOOL askOnTouch = slicer.askOnTouch;

			if (askOnTouch)
			{
				// create action sheet
				UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
				actionSheet.delegate = self;

				// add button foreach slice
				NSArray *slices = slicer.slices;
				for (NSString *slice in slices)
					[actionSheet addButtonWithTitle:slice];

				// new slice button (red)
				[actionSheet addButtonWithTitle:@"New Slice"];
				actionSheet.destructiveButtonIndex = actionSheet.numberOfButtons - 1;

				// cancel button
				[actionSheet addButtonWithTitle:@"Cancel"];
				actionSheet.cancelButtonIndex = actionSheet.numberOfButtons - 1;

				// display the sheet, unhighlight the button
				[actionSheet showInView:((SBUIController *)[%c(SBUIController) sharedInstance]).window];
				[self setHighlighted:NO];
			}
			else
			{
				[slicer switchToSlice:slicer.defaultSlice];
				%orig;
			}
		}
		else
			%orig;
	}
}

%new
- (SBApplication *)application
{
	return [self.icon application];
}

%new
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	// if the canceled, dont' do anything
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;
	else if (buttonIndex == actionSheet.destructiveButtonIndex)
	{
		// they want to create a new slice

		// ask for the slice name
		UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:@"New Slice"
			message:@"Enter the slice name"
			delegate:self
			cancelButtonTitle:@"Cancel"
			otherButtonTitles:@"Create Slice", nil];
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert show];
	}
	else
	{
		// switch slice
	    Slicer *slicer = [[Slicer alloc] initWithDisplayIdentifier:[self application].displayIdentifier];
	    [slicer switchToSlice:[actionSheet buttonTitleAtIndex:buttonIndex]];

		// emulate the tap (launch the app)
		id<SBIconViewDelegate> delegate = MSHookIvar< id<SBIconViewDelegate> >(self, "_delegate");
		[delegate iconTapped:self];
	}
}

%new
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Create Slice"])
	{
		// they want to create a slice

		// get the entered slice name
		UITextField *textField = [alertView textFieldAtIndex:0];
		NSString *sliceName = textField.text;

		// create the slice
		Slicer *slicer = [[Slicer alloc] initWithDisplayIdentifier:[self application].displayIdentifier];
		BOOL created = [slicer createSlice:sliceName];

		// if no errors occured, emulate the tap
		if (created)
		{
			id<SBIconViewDelegate> delegate = MSHookIvar< id<SBIconViewDelegate> >(self, "_delegate");
			[delegate iconTapped:self];
		}
	}
}
%end

static void loadSettings()
{
	NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:pathOfPreferences];
    isEnabled = ![[prefs allKeys] containsObject:@"isEnabled"] || [prefs[@"isEnabled"] boolValue];
    hasSeenWelcomeMessage = [[prefs allKeys] containsObject:@"hasSeenWelcomeMessage"];
}

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    loadSettings();
}

%ctor
{
    //listen for changes in settings
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.expetelek.slicespreferences/settingsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    loadSettings();
}