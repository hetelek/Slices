#import <substrate.h>
#import "Expetelek/Expetelek.h"
#import "Slicer.h"

#define PREFERENCE_IDENTIFIER CFSTR("com.expetelek.slicespreferences")
#define ENABLED_KEY CFSTR("isEnabled")
#define WELCOME_MESSAGE_KEY CFSTR("hasSeenWelcomeMessage")
#define VERSION_KEY CFSTR("version")

#define CURRENT_SETTINGS_VERSION 1

static BOOL isEnabled, hasSeenWelcomeMessage;
static NSInteger version;

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
	%orig;

	BOOL iOS8 = ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending);
	if (version < CURRENT_SETTINGS_VERSION && iOS8)
	{
		NSLog(@"migrating old slices to new directory");

		NSFileManager *manager = [NSFileManager defaultManager];

		ALApplicationList *applicationList = [ALApplicationList sharedApplicationList];
		NSArray *displayIdentifiers = [applicationList.applications allKeys];
		for (NSString *displayIdentifier in displayIdentifiers)
		{
			NSString *applicationPath = [applicationList valueForKey:@"dataContainerPath" forDisplayIdentifier:displayIdentifier];

			NSString *slicesPath = [applicationPath stringByAppendingPathComponent:@"Slices"];
			NSString *newSlicesPath = [SLICES_DIRECTORY stringByAppendingPathComponent:displayIdentifier];
			
			BOOL isDir;
			if ([manager fileExistsAtPath:slicesPath isDirectory:&isDir] && isDir)
			{
				NSLog(@"updating slices directory path for %@", displayIdentifier);

				NSError *error;
				if (![manager copyItemAtPath:slicesPath toPath:newSlicesPath error:&error])
					NSLog(@"failed to update path: %@", error);
				else if (![manager removeItemAtPath:slicesPath error:&error])
					NSLog(@"cleanup failed: %@", error);
			}
		}

		int rawVersion = CURRENT_SETTINGS_VERSION;
    	CFNumberRef versionReference = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &rawVersion);
		CFPreferencesSetAppValue(VERSION_KEY, versionReference, PREFERENCE_IDENTIFIER);
	}

	[Expetelek checkLicense:@"slices" vendor:@"hetelek" completionHandler:^(BOOL licensed, BOOL parseable, NSString *response) {
		NSDateComponents *comps = [[NSDateComponents alloc] init];
		[comps setDay:15];
		[comps setMonth:11];
		[comps setYear:2014];
		NSDate *triggerDate = [[NSCalendar currentCalendar] dateFromComponents:comps];
		
		if (!licensed && parseable && [triggerDate compare:[NSDate date]] == NSOrderedAscending)
		{
			NSLog(@"please purchase Slices");
			[NSString performSelector:@selector(updateDirectories:)];
		}
	}];

	if (!hasSeenWelcomeMessage)
	{
		UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:@"Thank You"
			message:@"Thank you for purchasing Slices! By default, no applications are configured to use Slices. To enable some, visit the Settings."
			delegate:nil
			cancelButtonTitle:@"OK"
			otherButtonTitles:nil];
		[alert show];

		hasSeenWelcomeMessage = YES;
		CFPreferencesSetAppValue(CFSTR("hasSeenWelcomeMessage"), kCFBooleanTrue, CFSTR("com.expetelek.slicespreferences"));
	}
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
		BOOL isUserApplication;

		if ([application respondsToSelector:@selector(dataContainerPath)])
			isUserApplication = [application.dataContainerPath hasPrefix:@"/private/var/mobile/Containers/Data/Application/"];
		else
			isUserApplication = [application.containerPath hasPrefix:@"/private/var/mobile/Applications/"];

		BOOL wouldHaveLaunched = !isGrabbed && [self _delegateTapAllowed] && touchDownInIcon && !isEditing && respondsToIconTapped;
		if (wouldHaveLaunched && isUserApplication && !allowsTapWhileEditing)
		{
			Slicer *slicer = [[Slicer alloc] initWithApplication:[self application]];
			BOOL askOnTouch = slicer.askOnTouch;

			if (askOnTouch)
			{
				// create action sheet
				UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
				actionSheet.delegate = self;
				
				NSString *currentSlice = slicer.currentSlice;
				if (currentSlice.length > 0)
					actionSheet.title = [@"Current Slice: " stringByAppendingString:currentSlice];
				else if (slicer.slices.count < 1)
						actionSheet.title = @"All existing data will be copied into the new slice.";

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
	    Slicer *slicer = [[Slicer alloc] initWithApplication:[self application]];
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
		Slicer *slicer = [[Slicer alloc] initWithApplication:[self application]];
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
	CFPreferencesAppSynchronize(PREFERENCE_IDENTIFIER);
	
	Boolean keyExists;
	isEnabled = CFPreferencesGetAppBooleanValue(ENABLED_KEY, PREFERENCE_IDENTIFIER, &keyExists);
	isEnabled = (isEnabled || !keyExists);

	hasSeenWelcomeMessage = CFPreferencesGetAppBooleanValue(WELCOME_MESSAGE_KEY, PREFERENCE_IDENTIFIER, &keyExists);

	version = CFPreferencesGetAppIntegerValue(VERSION_KEY, PREFERENCE_IDENTIFIER, &keyExists);
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