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
	if (_defaultSlice.length > 0)
	{
		NSString *defaultSliceFileName = [@"def_" stringByAppendingString:_defaultSlice];
		continueSettingSlice = [manager removeItemAtPath:[_applicationSlicesPath stringByAppendingPathComponent:defaultSliceFileName] error:NULL];
	}

	if (defaultSlice.length > 0 && continueSettingSlice)
	{
		NSString *defaultSliceFileName = [@"def_" stringByAppendingString:defaultSlice];
		if ([manager createFileAtPath:[_applicationSlicesPath stringByAppendingPathComponent:defaultSliceFileName] contents:nil attributes:nil])
			_defaultSlice = defaultSlice;
		else
			_defaultSlice = nil;
	}
}

- (NSString *)currentSlice
{
	NSString *currentSlice = nil;
	NSFileManager *manager = [NSFileManager defaultManager];
	NSArray *files = [manager contentsOfDirectoryAtPath:_applicationSlicesPath error:NULL];

	for (NSString *file in files)
	{
		NSString *fullPath = [_applicationSlicesPath stringByAppendingPathComponent:file];
		NSDictionary *attributes = [manager attributesOfItemAtPath:fullPath error:NULL];
		
		BOOL isRegularFile = [attributes[NSFileType] isEqualToString:NSFileTypeRegular];
		if (isRegularFile && [file hasPrefix:@"cur_"])
		{
			currentSlice = [file substringFromIndex:4];
			if (currentSlice.length < 1)
				currentSlice = nil;
			break;
		}
	}

	return currentSlice;
}

- (void)setCurrentSlice:(NSString *)newSliceName
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *currentSlice = self.currentSlice;
	if (currentSlice)
	{
		NSString *currentSliceFileName = [@"cur_" stringByAppendingString:currentSlice];
		NSString *currentSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:currentSliceFileName];

		if (![manager removeItemAtPath:currentSlicePath error:NULL])
			return;
	}

	if (newSliceName.length > 0)
	{
		NSString *newSliceFileName = [@"cur_" stringByAppendingString:newSliceName];
		NSString *newSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:newSliceFileName];
		[manager createFileAtPath:newSlicePath contents:nil attributes:nil];
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
	_defaultSlice = nil;

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

- (BOOL)cleanupMainDirectoryWithTargetSlicePath:(NSString *)cleanupSlicePath
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
		BOOL modifyDirectory = YES;
		for (NSString *suffix in IGNORE_SUFFIXES)
			if ([directory hasSuffix:suffix])
			{
				modifyDirectory = NO;
				break;
			}

		// if not, continue
		if (!modifyDirectory)
			continue;

		// get the directory
		NSString *directoryToModify = [_applicationPath stringByAppendingPathComponent:directory];
		
		// move/delete it
		if (cleanupSlicePath.length > 0)
		{
			if (![manager moveItemAtPath:directoryToModify toPath:[cleanupSlicePath stringByAppendingPathComponent:directory] error:&error])
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
		else if (![manager removeItemAtPath:directoryToModify error:&error])
		{
			errorOccurred = YES;
			NSLog(@"remove item error: %@", error);

			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:@"Error Removing"
				message:[NSString stringWithFormat:@"Sorry, but I had trouble removing '%@'.", directory]
				delegate:nil
				cancelButtonTitle:@"OK"
				otherButtonTitles:nil];
			[alert show];
		}
	}

	return !errorOccurred;
}

- (BOOL)checkIfOnlyOneComponent:(NSString *)fileName
{
	NSArray *pathComponents = [fileName pathComponents];
	if ([pathComponents count] != 1)
	{
		UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:@"Invalid Name"
			message:[NSString stringWithFormat:@"The name '%@' is invalid. Make sure it contains no slashes.", fileName]
			delegate:nil
			cancelButtonTitle:@"OK"
			otherButtonTitles:nil];
		[alert show];

		return NO;
	}

	return YES;
}

- (BOOL)switchToSlice:(NSString *)sliceName
{
	if (!sliceName)
		return NO;

	NSString *currentSliceAttempt = self.currentSlice;
	if ([currentSliceAttempt isEqualToString:sliceName])
		return YES;

	[self killApplication];

	BOOL errorOccurred = NO;
	NSError *error;
	NSFileManager *manager = [NSFileManager defaultManager];

	// get slice paths
	NSString *targetSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:sliceName];
	if (currentSliceAttempt.length > 0)
	{
		// cleanup the directory
		NSString *currentSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:currentSliceAttempt];
		[self cleanupMainDirectoryWithTargetSlicePath:currentSlicePath];
	}
	
	// get all the directories in the slice
	NSArray *directoriesToLink = [manager contentsOfDirectoryAtPath:targetSlicePath error:NULL];
	for (NSString *directory in directoriesToLink)
	{
		// move the directory to the application directory
		NSString *currentPath = [targetSlicePath stringByAppendingPathComponent:directory];
		if (![manager moveItemAtPath:currentPath toPath:[_applicationPath stringByAppendingPathComponent:directory] error:&error])
		{
			errorOccurred = YES;
			NSLog(@"link path error: %@", error);

			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:@"Linking Error"
				message:[NSString stringWithFormat:@"Failed to move '%@' directory.", directory]
				delegate:nil
				cancelButtonTitle:@"OK"
				otherButtonTitles:nil];
			[alert show];
		}
	}

	if (!errorOccurred)
		self.currentSlice = sliceName;

	return !errorOccurred;
}

- (BOOL)createSlice:(NSString *)sliceName
{
	if (![self checkIfOnlyOneComponent:sliceName])
		return NO;

	BOOL errorOccurred = NO;
	NSError *error;
	NSFileManager *manager = [NSFileManager defaultManager];

	NSString *targetSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:sliceName];
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
		NSString *currentSliceAttempt = self.currentSlice;
		if (currentSliceAttempt.length < 1)
		{
			for (NSString *directory in CREATE_AND_LINK_DIRECTORIES)
				[manager createDirectoryAtPath:[_applicationPath stringByAppendingPathComponent:directory] withIntermediateDirectories:YES attributes:nil error:&error];

			self.currentSlice = sliceName;
			if (_defaultSlice.length < 1)
				self.defaultSlice = sliceName;

			return YES;
		}

		[self killApplication];

		// cleanup the directory
		NSString *currentSlicePath = [_applicationSlicesPath stringByAppendingPathComponent:currentSliceAttempt];
		[self cleanupMainDirectoryWithTargetSlicePath:currentSlicePath];
		
		// create a directory for everything reasonable, and link it
		for (NSString *directory in CREATE_AND_LINK_DIRECTORIES)
		{
			// get the directory path to create
			NSString *currentDirectoryFullPath = [_applicationPath stringByAppendingPathComponent:directory];

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
		}

		self.currentSlice = sliceName;
		if (_defaultSlice.length < 1)
			self.defaultSlice = sliceName;
	}

	return !errorOccurred;
}

- (BOOL)deleteSlice:(NSString *)sliceName
{
	if (![self checkIfOnlyOneComponent:sliceName])
		return NO;

	[self killApplication];

	// cleanup
	NSString *currentSlice = self.currentSlice;
	if ([sliceName isEqualToString:currentSlice])
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
	
	NSArray *slices = self.slices;
	NSString *defaultSlice = self.defaultSlice;
	
	if ([defaultSlice isEqualToString:sliceName])
	{
		if (slices.count < 1)
			self.defaultSlice = nil;
		else
			self.defaultSlice = slices[0];
	}

	if ([currentSlice isEqualToString:sliceName])
	{
		if (slices.count < 1)
			self.currentSlice = nil;
		else if (defaultSlice.length > 0)
			self.currentSlice = self.defaultSlice;
		else
			self.currentSlice = slices[0];
	}

	[self reloadData];
	return YES;
}

- (BOOL)renameSlice:(NSString *)originaSliceName toName:(NSString *)targetSliceName
{
	if (![self checkIfOnlyOneComponent:originaSliceName] || ![self checkIfOnlyOneComponent:targetSliceName])
		return NO;

	NSFileManager *manager = [NSFileManager defaultManager];

	NSString *originalSliceDirectoryFullPath = [_applicationSlicesPath stringByAppendingPathComponent:originaSliceName];
	NSString *targetSliceDirectoryFullPath = [_applicationSlicesPath stringByAppendingPathComponent:targetSliceName];

	NSError *error;
	if (![manager moveItemAtPath:originalSliceDirectoryFullPath toPath:targetSliceDirectoryFullPath error:&error])
	{
		if (error.code == NSFileWriteFileExistsError)
		{
			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:@"Already Exists"
				message:[NSString stringWithFormat:@"There is already a slice named '%@'.", targetSliceName]
				delegate:nil
				cancelButtonTitle:@"OK"
				otherButtonTitles:nil];
			[alert show];
		}
		else
		{
			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:@"Renaming Error"
				message:[NSString stringWithFormat:@"An error occurred when renaming '%@'.\n\n%@", originaSliceName, error]
				delegate:nil
				cancelButtonTitle:@"OK"
				otherButtonTitles:nil];
			[alert show];
		}

		return NO;
	}
	
	NSString *currentSlice = self.currentSlice;
	if ([currentSlice isEqualToString:originaSliceName])
		self.currentSlice = targetSliceName;
	if ([currentSlice isEqualToString:originaSliceName])
		self.defaultSlice = targetSliceName;
	
	return YES;
}
@end