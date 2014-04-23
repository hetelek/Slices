#import <substrate.h>
#import "SpringBoardHeaders.h"

@interface SBIconView (New)
@property (readonly) SBApplication *application;

- (void)killApplication;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
@end

extern "C" void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *app, int a, int b, NSString *description);

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
				if (![self allowsTapWhileEditing] && [[application containerPath] hasPrefix:@"/private/var/mobile/Applications/"])
				{
					// get crucial directories
					NSString *applicationDirectory = [application containerPath];
					NSString *slicesDirectory = [applicationDirectory stringByAppendingPathComponent:@"Slices"];

					// get all the current slices
					NSArray *slices = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:slicesDirectory error:NULL];

					// create action sheet
					UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
					actionSheet.delegate = self;

					// add button foreach slice
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
- (void)killApplication
{
	NSString *displayIdentifier = [self application].displayIdentifier;
	BKSTerminateApplicationForReasonAndReportWithDescription(displayIdentifier, 5, 1, @"Killed from Slices");
	[NSThread sleepForTimeInterval:0.1];
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
		// they want to switch to a slice

		// get the application, kill it
		SBApplication *application = [self application];
		[self killApplication];

	    // get the application directory
		NSString *applicationDirectory = [application containerPath];
		
		// get the current selected slice's directory
		NSString *selectedSliceDirectory = [applicationDirectory stringByAppendingPathComponent:@"Slices"];
		selectedSliceDirectory = [selectedSliceDirectory stringByAppendingPathComponent:[actionSheet buttonTitleAtIndex:buttonIndex]];

		NSFileManager *manager = [NSFileManager defaultManager];

		// get all the directories in the slice
		NSArray *directoriesToLink = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:selectedSliceDirectory error:NULL];
		for (NSString *directory in directoriesToLink)
		{
			// if that directory already exists, delete it
			NSString *linkDestination = [applicationDirectory stringByAppendingPathComponent:directory];
			if ([manager fileExistsAtPath:linkDestination])
			{
				NSError *error;
				if (![manager removeItemAtPath:linkDestination error:&error])
					NSLog(@"remove link error: %@", error);
			}

			// symbolically link the directory
			NSString *destinationPath = [selectedSliceDirectory stringByAppendingPathComponent:directory];

			NSError *error;
			if (![manager createSymbolicLinkAtPath:linkDestination withDestinationPath:destinationPath error:&error])
				NSLog(@"link path error: %@", error);
		}

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

		BOOL errorOccurred = NO;
		NSError *error;

		// get the entered slice name
		UITextField *textField = [alertView textFieldAtIndex:0];
		NSString *sliceName = textField.text;

		// get the application
		SBApplication *application = [self application];
		NSString *applicationDirectory = [application containerPath];

		// get the target slice direcotry
		NSString *sliceDirectory = [applicationDirectory stringByAppendingPathComponent:@"Slices"];
		sliceDirectory = [sliceDirectory stringByAppendingPathComponent:sliceName];

		NSFileManager *manager = [NSFileManager defaultManager];
		if ([manager fileExistsAtPath:sliceDirectory])
		{
			// already exists, tell them

			errorOccurred = YES;
			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:@"Already Exists"
				message:[NSString stringWithFormat:@"There is already a slice named '%@'.", sliceName]
				delegate:nil
				cancelButtonTitle:@"OK"
				otherButtonTitles:nil];
			[alert show];
		}
		else
		{
			// kill the application
			[self killApplication];

			// prematurely create the slice directory
			[manager createDirectoryAtPath:sliceDirectory withIntermediateDirectories:YES attributes:nil error:NULL];

	    	// constants
	    	NSArray *IGNORE_SUFFIXES = @[ @".app", @"iTunesMetadata.plist", @"iTunesArtwork", @"Slices" ];
			NSArray *CREATE_AND_LINK_DIRECTORIES = @[ @"tmp", @"Documents", @"StoreKit", @"Library" ];

			// get the directories we want to (potentially) delete
	    	NSArray *directoriesToDelete = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:applicationDirectory error:NULL];
	    	for (NSString *directory in directoriesToDelete)
			{
				// check if we should delete the directory
				BOOL removeDirectory = YES;
				for (NSString *suffix in IGNORE_SUFFIXES)
					if ([directory hasSuffix:suffix])
					{
						removeDirectory = NO;
						break;
					}

				// if not, continue
				if (!removeDirectory)
					continue;

				// get the directory and its attributes
				NSString *directoryToDelete = [applicationDirectory stringByAppendingPathComponent:directory];
				NSDictionary *attributes = [manager attributesOfItemAtPath:directoryToDelete error:NULL];
				
				// if it's not a symbolic link, copy it
				if (![attributes[NSFileType] isEqualToString:NSFileTypeSymbolicLink])
				{
					// try and move it, tell them if it fails
					if (![manager moveItemAtPath:directoryToDelete toPath:[sliceDirectory stringByAppendingPathComponent:directory] error:&error])
					{
						NSLog(@"move item error: %@", error);
						UIAlertView *alert = [[UIAlertView alloc]
							initWithTitle:@"Error Preserving"
							message:[NSString stringWithFormat:@"Sorry, but I had trouble preserving '%@'.", directory]
							delegate:nil
							cancelButtonTitle:@"OK"
							otherButtonTitles:nil];
						[alert show];
					}
				}
				else if (![manager removeItemAtPath:directoryToDelete error:&error])
				{
					// failed to delete the directory
					NSLog(@"remove directory error: %@", error);

					errorOccurred = YES;
					UIAlertView *alert = [[UIAlertView alloc]
						initWithTitle:@"Cleaning Error"
						message:[NSString stringWithFormat:@"Failed to delete '%@' link.", directory]
						delegate:nil
						cancelButtonTitle:@"OK"
						otherButtonTitles:nil];
					[alert show];
				}
			}

			// create a directory for everything reasonable, and link it
			for (NSString *directory in CREATE_AND_LINK_DIRECTORIES)
			{
				// get the directory path to create
				NSString *currentDirectoryFullPath = [sliceDirectory stringByAppendingPathComponent:directory];

				// attempt to create the directory
				if (![manager createDirectoryAtPath:currentDirectoryFullPath withIntermediateDirectories:YES attributes:nil error:&error])
				{
					// directory creation failed, tell them
					NSLog(@"directory creation error: %@", error);

					errorOccurred = YES;
					UIAlertView *alert = [[UIAlertView alloc]
						initWithTitle:@"Creation Error"
						message:[NSString stringWithFormat:@"Failed to create '%@' directory.", directory]
						delegate:nil
						cancelButtonTitle:@"OK"
						otherButtonTitles:nil];
					[alert show];
				}
				else
				{
					// create the symbolic link
					NSString *linkPath = [applicationDirectory stringByAppendingPathComponent:directory];
					if (![manager createSymbolicLinkAtPath:linkPath withDestinationPath:currentDirectoryFullPath error:&error])
					{
						// failed to symbilically link paths, tell them
						NSLog(@"symbolically linking error: %@", error);

						errorOccurred = YES;
						UIAlertView *alert = [[UIAlertView alloc]
							initWithTitle:@"Linking Error"
							message:[NSString stringWithFormat:@"Failed to link '%@' directory.", directory]
							delegate:nil
							cancelButtonTitle:@"OK"
							otherButtonTitles:nil];
						[alert show];
					}
				}
			}
		}

		// if no errors occured, then tell them
		if (!errorOccurred)
		{
			id<SBIconViewDelegate> delegate = MSHookIvar< id<SBIconViewDelegate> >(self, "_delegate");
			[delegate iconTapped:self];
		}
	}
}
%end