#import "Slicer.h"

@interface Slicer ()
@property (readwrite) NSString *displayIdentifier;

@property NSString *applicationDirectory;
@property NSString *slicesDirectory;

@property (assign) BOOL iOS8;
@property (assign) BOOL ignoreNextKill;

@property SBApplication *application;
@end

extern "C" void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *app, int a, int b, NSString *description);

@implementation Slicer : NSObject
- (instancetype)initWithApplication:(SBApplication *)application
{
	self = [super init];

	self.iOS8 = ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending);

	self.application = application;
	self.displayIdentifier = application.displayIdentifier;

	// get application directory
	if ([application respondsToSelector:@selector(dataContainerPath)])
		self.applicationDirectory = [application dataContainerPath];
	else
	{
		ALApplicationList *applicationList = [ALApplicationList sharedApplicationList];
		self.applicationDirectory = [[applicationList valueForKey:@"path" forDisplayIdentifier:self.displayIdentifier] stringByDeletingLastPathComponent];
	}

	if (!self.applicationDirectory)
		return nil;

	// get slices directory
	if (self.iOS8)
		self.slicesDirectory = [SLICES_DIRECTORY stringByAppendingPathComponent:_displayIdentifier];
	else
		self.slicesDirectory = [self.applicationDirectory stringByAppendingPathComponent:@"Slices"];

	return self;
}

- (instancetype)initWithDisplayIdentifier:(NSString *)displayIdentifier
{
	self = [super init];

	self.iOS8 = ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending);

	self.application = nil;
	self.displayIdentifier = displayIdentifier;

	// get application directory
	ALApplicationList *applicationList = [ALApplicationList sharedApplicationList];
	if (self.iOS8)
		self.applicationDirectory = [applicationList valueForKey:@"dataContainerPath" forDisplayIdentifier:displayIdentifier];
	else
		self.applicationDirectory = [[applicationList valueForKey:@"path" forDisplayIdentifier:displayIdentifier] stringByDeletingLastPathComponent];

	if (!self.applicationDirectory)
		return nil;

	// get slices directory
	if (self.iOS8)
		self.slicesDirectory = [SLICES_DIRECTORY stringByAppendingPathComponent:displayIdentifier];
	else
		self.slicesDirectory = [self.applicationDirectory stringByAppendingPathComponent:@"Slices"];

	return self;
}

- (NSArray *)slices
{
	NSMutableArray *slices = [[NSMutableArray alloc] init];

	// get all directories in slices directory
	NSFileManager *manager = [NSFileManager defaultManager];
	NSArray *files = [manager contentsOfDirectoryAtPath:self.slicesDirectory error:NULL];
	for (NSString *file in files)
	{
		NSString *fullPath = [self.slicesDirectory stringByAppendingPathComponent:file];
		NSDictionary *attributes = [manager attributesOfItemAtPath:fullPath error:NULL];
		BOOL isDirectory = [attributes[NSFileType] isEqualToString:NSFileTypeDirectory];

		if (isDirectory)
			[slices addObject:file];
	}

	return slices;
}

- (NSString *)defaultSlice
{
	SliceSetting *defaultSliceSetting = [[SliceSetting alloc] initWithPrefix:@"def_"];
	return [defaultSliceSetting getValueInDirectory:self.slicesDirectory];
}

- (void)setDefaultSlice:(NSString *)defaultSlice
{
	SliceSetting *defaultSliceSetting = [[SliceSetting alloc] initWithPrefix:@"def_"];
	[defaultSliceSetting setValueInDirectory:self.slicesDirectory value:defaultSlice];
}

- (NSString *)currentSlice
{
	SliceSetting *currentSliceSetting = [[SliceSetting alloc] initWithPrefix:@"cur_"];
	return [currentSliceSetting getValueInDirectory:self.slicesDirectory];
}

- (void)setCurrentSlice:(NSString *)sliceName
{
	SliceSetting *currentSliceSetting = [[SliceSetting alloc] initWithPrefix:@"cur_"];
	[currentSliceSetting setValueInDirectory:self.slicesDirectory value:sliceName];	
}

- (void)setAskOnTouch:(BOOL)askOnTouch
{
	SliceSetting *askOnTouchSliceSetting = [[SliceSetting alloc] initWithPrefix:@"e"];

	NSString *stringValue = (askOnTouch) ? @"1" : @"0";
	[askOnTouchSliceSetting setValueInDirectory:self.slicesDirectory value:stringValue];
}

- (BOOL)askOnTouch
{
	SliceSetting *askOnTouchSliceSetting = [[SliceSetting alloc] initWithPrefix:@"e"];
	return [[askOnTouchSliceSetting getValueInDirectory:self.slicesDirectory] isEqualToString:@"1"];
}

- (void)killApplication
{
	if (self.ignoreNextKill)
	{
		self.ignoreNextKill = NO;
		return;
	}

	// if FBApplicationProcess has 'stop', use that
	Class FBApplicationProcessClass = objc_getClass("FBApplicationProcess");
	if ([FBApplicationProcessClass instancesRespondToSelector:@selector(stop)])
	{
		if (self.application)
		{
			FBApplicationProcess *process = MSHookIvar<FBApplicationProcess *>(self.application, "_process");
			[process stop];
		}
	}
	else
		BKSTerminateApplicationForReasonAndReportWithDescription(self.displayIdentifier, 5, NO, @"Killed from Slices");

	// must kill this in iOS 8
	if (self.iOS8)
	{
		char * const argv[4] = {(char *const)"launchctl", (char *const)"stop", (char *const)"com.apple.cfprefsd.xpc.daemon", NULL};
		NSLog(@"launchctl call: %i", posix_spawnp(NULL, (char *const)"launchctl", NULL, NULL, argv, NULL));
	}

	[NSThread sleepForTimeInterval:0.1];
}

- (BOOL)cleanupMainDirectoryWithTargetSlicePath:(NSString *)cleanupSlicePath
{
	NSString *currentSlice = self.currentSlice;

	// get current slice path (if current slice exists)
	NSString *currentSlicePath;
	if (currentSlice.length > 0)
		currentSlicePath = [self.slicesDirectory stringByAppendingPathComponent:currentSlice];
	else
		currentSlicePath = nil;

	// migrate/delete current app data to current slice path
	FolderMigrator *migrator = [[FolderMigrator alloc] initWithSourcePath:self.applicationDirectory destinationPath:currentSlicePath];
	migrator.ignoreSuffixes = @[ @".app", @"iTunesMetadata.plist", @"iTunesArtwork", @"Slices", @".com.apple.mobile_container_manager.metadata.plist" ];
	return [migrator executeMigration];
}

- (BOOL)onlyOneComponent:(NSString *)name
{
	NSArray *pathComponents = [name pathComponents];
	return [pathComponents count] == 1;
}

- (BOOL)switchToSlice:(NSString *)targetSliceName
{
	// make sure they give us a target slice
	if (targetSliceName.length < 1)
		return NO;

	// see if we're already on the slice
	NSString *currentSlice = self.currentSlice;
	if ([currentSlice isEqualToString:targetSliceName])
		return YES;

	[self killApplication];

	// cleanup current slice
	if (currentSlice.length > 0)
	{
		NSString *currentSlicePath = [self.slicesDirectory stringByAppendingPathComponent:currentSlice];
		[self cleanupMainDirectoryWithTargetSlicePath:currentSlicePath];
	}
	
	// migrate new slice data into app directory
	NSString *targetSlicePath = [self.slicesDirectory stringByAppendingPathComponent:targetSliceName];
	FolderMigrator *migrator = [[FolderMigrator alloc] initWithSourcePath:targetSlicePath destinationPath:self.applicationDirectory];
	BOOL success = [migrator executeMigration];

	// update current slice (if successful)
	if (success)
		self.currentSlice = targetSliceName;

	return NO;
}

- (BOOL)createSlice:(NSString *)newSliceName
{
	// check for invalid name
	if (![self onlyOneComponent:newSliceName])
		return NO;

	NSFileManager *manager = [NSFileManager defaultManager];

	// make sure it doesn't already exist
	NSString *newSlicePath = [self.slicesDirectory stringByAppendingPathComponent:newSliceName];
	if ([manager fileExistsAtPath:newSlicePath])
		return NO;

	// create directory
	[manager createDirectoryAtPath:newSlicePath withIntermediateDirectories:YES attributes:nil error:NULL];
	
	NSArray *DIRECTORIES = @[ @"tmp", @"Documents", @"StoreKit", @"Library" ];
	NSString *currentSlice = self.currentSlice;
	if (currentSlice.length < 1)
	{
		for (NSString *directory in DIRECTORIES)
			[manager createDirectoryAtPath:[self.applicationDirectory stringByAppendingPathComponent:directory] withIntermediateDirectories:YES attributes:nil error:NULL];

		self.currentSlice = newSliceName;
		self.defaultSlice = newSliceName;

		return YES;
	}

	[self killApplication];
	
	// cleanup current slice
	NSString *currentSlicePath = [self.slicesDirectory stringByAppendingPathComponent:currentSlice];
	[self cleanupMainDirectoryWithTargetSlicePath:currentSlicePath];
	
	// create app data directories
	BOOL success = YES;
	for (NSString *directory in DIRECTORIES)
	{
		NSString *currentDirectoryFullPath = [self.applicationDirectory stringByAppendingPathComponent:directory];
		if (![manager createDirectoryAtPath:currentDirectoryFullPath withIntermediateDirectories:YES attributes:nil error:NULL])
			success = NO;
	}

	// update current/default slice
	self.currentSlice = newSliceName;
	if (self.defaultSlice.length < 1)
		self.defaultSlice = newSliceName;

	return success;
}

- (BOOL)deleteSlice:(NSString *)sliceName
{
	// check for invalid name
	if (![self onlyOneComponent:sliceName])
		return NO;

	// if current slice, cleanup app directory
	NSString *currentSlice = self.currentSlice;
	if ([sliceName isEqualToString:currentSlice])
	{
		[self killApplication];
		[self cleanupMainDirectoryWithTargetSlicePath:nil];
	}
	
	// remove slice directory
	NSString *slicePath = [self.slicesDirectory stringByAppendingPathComponent:sliceName];
	if (![[NSFileManager defaultManager] removeItemAtPath:slicePath error:NULL])
		return NO;
	
	NSArray *slices = self.slices;
	NSString *defaultSlice = self.defaultSlice;
	
	// update default slice
	if ([defaultSlice isEqualToString:sliceName])
	{
		if (slices.count > 0)
		{
			self.defaultSlice = slices[0];
			defaultSlice = slices[0];
		}
		else
		{
			self.defaultSlice = nil;
			defaultSlice = nil;
		}
	}

	// update current slice
	if ([currentSlice isEqualToString:sliceName])
	{
		self.currentSlice = nil;
		self.ignoreNextKill = YES;

		if (defaultSlice.length > 0)
			[self switchToSlice:defaultSlice];
		else
			[self switchToSlice:slices[0]];
	}

	self.ignoreNextKill = NO;
	return YES;
}

- (BOOL)renameSlice:(NSString *)originaSliceName toName:(NSString *)targetSliceName
{
	if (![self onlyOneComponent:originaSliceName] || ![self onlyOneComponent:targetSliceName])
		return NO;

	// get original/target slice path
	NSString *originalSlicePath = [self.slicesDirectory stringByAppendingPathComponent:originaSliceName];
	NSString *targetSlicePath = [self.slicesDirectory stringByAppendingPathComponent:targetSliceName];

	// move slice data
	NSFileManager *manager = [NSFileManager defaultManager];
	if (![manager moveItemAtPath:originalSlicePath toPath:targetSlicePath error:NULL])
		return NO;
	
	// update current/default slice
	if ([self.currentSlice isEqualToString:originaSliceName])
		self.currentSlice = targetSliceName;
	if ([self.defaultSlice isEqualToString:originaSliceName])
		self.defaultSlice = targetSliceName;
	
	return YES;
}
@end
