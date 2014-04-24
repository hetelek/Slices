#import <substrate.h>
#import "Slicer.h"

static BOOL isEnabled;

@interface SBIconView (New)
@property (readonly) SBApplication *application;

- (void)killApplication;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
@end

%hook SBIconView
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	// the uncommented parts are from Apple

	BOOL touchDownInIcon = (BOOL)(MSHookIvar<unsigned int>(self, "_touchDownInIcon") & 0xFF);
	BOOL isGrabbed = (BOOL)(MSHookIvar<unsigned int>(self, "_isGrabbed") & 8);
	if (isGrabbed)
		[[%c(SBUIController) sharedInstance].window _updateInterfaceOrientationFromDeviceOrientation];
	
	[self cancelLongPressTimer];

	if (!isGrabbed && [self _delegateTapAllowed])
	{
		BOOL isEditing = (BOOL)(MSHookIvar<unsigned int>(self, "_isEditing") & 2);
		if (touchDownInIcon && ([self allowsTapWhileEditing] || !isEditing))
		{
			id<SBIconViewDelegate> delegate = MSHookIvar< id<SBIconViewDelegate> >(self, "_delegate");
			if ([delegate respondsToSelector:@selector(iconTapped:)])
			{
				// get the applicaiton, check if it's a user application
				SBApplication *application = [self application];
				if (isEnabled && ![self allowsTapWhileEditing] && [[application containerPath] hasPrefix:@"/private/var/mobile/Applications/"])
				{
					Slicer *slicer = [[Slicer alloc] initWithDisplayIdentifier:application.displayIdentifier];

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

					// display the sheet
					[actionSheet showInView:[%c(SBUIController) sharedInstance].window];
				}
				else
				{
					[delegate iconTapped:self];
					return;
				}
			}
		}
	}
	else
		[self _delegateTouchEnded:NO];

	[self setHighlighted:NO];
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

static void loadSettings(){
	NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.expetelek.slicespreferences.plist"];
    isEnabled = ![[prefs allKeys] containsObject:@"isEnabled"] || [prefs[@"isEnabled"] boolValue];
}

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo){
    loadSettings();
}

%ctor{
    //listen for changes in settings
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.expetelek.slicespreferences/settingsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    loadSettings();
}