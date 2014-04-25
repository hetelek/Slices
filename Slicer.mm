#import "Slicer.h"

@interface Slicer ()
{
	NSString *_applicationPath;
	NSString *_applicationSlicesPath;
	NSString *_displayIdentifier;
	NSString *_defaultSlice;
	NSArray *_slices;
	BOOL _askOnTouch;
}
@end

extern "C" void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *app, int a, int b, NSString *description);

@implementation Slicer : NSObject
- (instancetype)initWithDisplayIdentifier:(NSString *)displayIdentifier
{
	self = [super init];
	_displayIdentifier = displayIdentifier;

	ALApplicationList *applicationList = [ALApplicationList sharedApplicationList];
	_applicationPath = [[applicationList valueForKey:@"path" forDisplayIdentifier:displayIdentifier] stringByDeletingLastPathComponent];

	if (_applicationPath == nil)
		return nil;

	_applicationSlicesPath = [_applicationPath stringByAppendingPathComponent:@"Slices"];

	return self;
}

- (NSArray *)slices
{
	[self reloadData];
	return _slices;
}

- (NSString *)defaultSlice
{
	[self reloadData];

	if (_defaultSlice == nil && _slices.count > 0)
		return _slices[0];

	return _defaultSlice;
}

- (void)setDefaultSlice:(NSString *)defaultSlice
{
	[self reloadData];

	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL continueSettingSlice = YES;
	if (_defaultSlice)
	{
		NSString *defaultSliceFileName = [@"def_" stringByAppendingString:_defaultSlice];
		continueSettingSlice = [manager removeItemAtPath:[_applicationSlicesPath stringByAppendingPathComponent:defaultSliceFileName] error:NULL];
	}

	if (continueSettingSlice)
	{
		NSString *defaultSliceFileName = [@"def_" stringByAppendingString:defaultSlice];
		if ([manager createFileAtPath:[_applicationSlicesPath stringByAppendingPathComponent:defaultSliceFileName] contents:nil attributes:nil])
			_defaultSlice = defaultSlice;
		else
			_defaultSlice = nil;
	}
}

- (void)setAskOnTouch:(BOOL)askOnTouch
{
	[self reloadData];

	NSFileManager *manager = [NSFileManager defaultManager];
	if (![manager removeItemAtPath:[_applicationSlicesPath stringByAppendingPathComponent:(_askOnTouch ? @"e1" : @"e0")] error:NULL])
		[manager removeItemAtPath:[_applicationSlicesPath stringByAppendingPathComponent:(!_askOnTouch ? @"e1" : @"e0")] error:NULL];

	[manager createDirectoryAtPath:_applicationSlicesPath withIntermediateDirectories:YES attributes:nil error:NULL];
	if ([manager createFileAtPath:[_applicationSlicesPath stringByAppendingPathComponent:(askOnTouch ? @"e1" : @"e0")] contents:nil attributes:nil])
		_askOnTouch = askOnTouch;
}

- (BOOL)askOnTouch
{
	[self reloadData];

	return _askOnTouch;
}

- (void)reloadData
{
	BOOL foundDefault = NO;
	BOOL foundAskOnTouch = NO;

	NSFileManager *manager = [NSFileManager defaultManager];

	NSArray *files = [manager contentsOfDirectoryAtPath:_applicationSlicesPath error:NULL];
	NSMutableArray *slices = [[NSMutableArray alloc] init];
	for (NSString *file in files)
	{
		if (!foundDefault || !foundAskOnTouch)
		{
			NSString *fullPath = [_applicationSlicesPath stringByAppendingPathComponent:file];
			NSDictionary *attributes = [manager attributesOfItemAtPath:fullPath error:NULL];
			
			BOOL isRegularFile = [attributes[NSFileType] isEqualToString:NSFileTypeRegular];
			if (isRegularFile)
			{
				if ([file hasPrefix:@"def_"])
				{
					_defaultSlice = [file substringFromIndex:4];
					if (_defaultSlice.length > 0)
					{
						NSString *defaultSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:_defaultSlice];
						if (![manager fileExistsAtPath:defaultSlicePath])
						{
							_defaultSlice = nil;
							[manager removeItemAtPath:fullPath error:NULL];
						}
						else
							foundDefault = YES;
					}
				}
				else if ([file hasPrefix:@"e"] && file.length == 2)
				{
					foundAskOnTouch = YES;

					if ([file isEqualToString:@"e0"])
						_askOnTouch = NO;
					else if ([file isEqualToString:@"e1"])
						_askOnTouch = YES;
					else
						foundAskOnTouch = NO;
				}

				continue;
			}
		}

		[slices addObject:file];
	}

	if (!foundAskOnTouch)
		_askOnTouch = NO;

	_slices = [slices copy];
}

- (void)killApplication
{
	BKSTerminateApplicationForReasonAndReportWithDescription(_displayIdentifier, 5, 1, @"Killed from Slices");
	[NSThread sleepForTimeInterval:0.1];
}

- (BOOL)cleanupMainDirectoryWithTargetSlicePath:(NSString *)targetSlicePath
{
	NSArray *IGNORE_SUFFIXES = @[ @".app", @"iTunesMetadata.plist", @"iTunesArtwork", @"Slices" ];

	BOOL errorOccurred = NO;
	NSError *error;
	NSFileManager *manager = [NSFileManager defaultManager];

	// get the directories we want to (potentially) delete
	NSArray *directoriesToDelete = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_applicationPath error:NULL];
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
		NSString *directoryToDelete = [_applicationPath stringByAppendingPathComponent:directory];
		NSDictionary *attributes = [manager attributesOfItemAtPath:directoryToDelete error:NULL];
		
		// if it's not a symbolic link, copy it (if they specified a path)
		BOOL isSymbolicLink = [attributes[NSFileType] isEqualToString:NSFileTypeSymbolicLink];
		if (targetSlicePath && !isSymbolicLink)
		{
			// try and move it, tell them if it fails
			if (![manager moveItemAtPath:directoryToDelete toPath:[targetSlicePath stringByAppendingPathComponent:directory] error:&error])
			{
				errorOccurred = YES;
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
		else if (isSymbolicLink && ![manager removeItemAtPath:directoryToDelete error:&error])
		{
			// failed to delete the directory
			errorOccurred = YES;
			NSLog(@"remove directory error: %@", error);

			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:@"Cleaning Error"
				message:[NSString stringWithFormat:@"Failed to delete '%@' link.", directory]
				delegate:nil
				cancelButtonTitle:@"OK"
				otherButtonTitles:nil];
			[alert show];
		}
	}

	return !errorOccurred;
}

- (BOOL)switchToSlice:(NSString *)sliceName
{
	if (!sliceName)
		return NO;

	[self killApplication];

	BOOL errorOccured = NO;
	NSFileManager *manager = [NSFileManager defaultManager];

	// get target slice path
	NSString *targetSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:sliceName];

	// get all the directories in the slice
	NSArray *directoriesToLink = [manager contentsOfDirectoryAtPath:targetSlicePath error:NULL];
	for (NSString *directory in directoriesToLink)
	{
		// if that directory already exists, delete it
		NSString *linkDestination = [_applicationPath stringByAppendingPathComponent:directory];
		if ([manager fileExistsAtPath:linkDestination])
		{
			NSError *error;
			if (![manager removeItemAtPath:linkDestination error:&error])
				NSLog(@"remove link error: %@", error);
		}

		// symbolically link the directory
		NSString *destinationPath = [targetSlicePath stringByAppendingPathComponent:directory];

		NSError *error;
		if (![manager createSymbolicLinkAtPath:linkDestination withDestinationPath:destinationPath error:&error])
		{
			errorOccured = YES;
			NSLog(@"link path error: %@", error);

			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:@"Linking Error"
				message:[NSString stringWithFormat:@"Failed to link '%@' directory.", directory]
				delegate:nil
				cancelButtonTitle:@"OK"
				otherButtonTitles:nil];
			[alert show];
		}
	}

	return !errorOccured;
}

- (BOOL)createSlice:(NSString *)sliceName
{
	[self killApplication];

	BOOL errorOccurred = NO;
	NSError *error;

	NSString *targetSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:sliceName];

	NSFileManager *manager = [NSFileManager defaultManager];
	if ([manager fileExistsAtPath:targetSlicePath])
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
		// prematurely create the slice directory
		[manager createDirectoryAtPath:targetSlicePath withIntermediateDirectories:YES attributes:nil error:NULL];

    	// constants
		NSArray *CREATE_AND_LINK_DIRECTORIES = @[ @"tmp", @"Documents", @"StoreKit", @"Library" ];

		// cleanup
		[self cleanupMainDirectoryWithTargetSlicePath:targetSlicePath];
		
		// create a directory for everything reasonable, and link it
		for (NSString *directory in CREATE_AND_LINK_DIRECTORIES)
		{
			// get the directory path to create
			NSString *currentDirectoryFullPath = [targetSlicePath stringByAppendingPathComponent:directory];

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
				NSString *linkPath = [_applicationPath stringByAppendingPathComponent:directory];
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

	return !errorOccurred;
}

- (BOOL)deleteSlice:(NSString *)sliceName
{
	[self killApplication];

	// cleanup
	[self cleanupMainDirectoryWithTargetSlicePath:nil];

	// try and remove the direcotry
	NSError *error;
	if (![[NSFileManager defaultManager] removeItemAtPath:[_applicationSlicesPath stringByAppendingPathComponent:sliceName] error:&error])
	{
		NSLog(@"delete slice error: %@", error);
		
		UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:@"Deletion Failed"
			message:[NSString stringWithFormat:@"Failed to delete '%@' slice.\n\n%@", sliceName, error]
			delegate:nil
			cancelButtonTitle:@"OK"
			otherButtonTitles:nil];
		[alert show];

		return NO;
	}

	[self reloadData];
	return YES;
}
@end