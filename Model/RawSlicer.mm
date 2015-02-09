#import "RawSlicer.h"

@implementation RawSlicer : NSObject
- (instancetype)initWithWorkingDirectory:(NSString *)workingDirectory slicesDirectory:(NSString *)slicesDirectory
{
	self = [super init];

	self.workingDirectory = workingDirectory;
	self.slicesDirectory = slicesDirectory;

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

- (BOOL)cleanupMainDirectoryWithTargetSlicePath:(NSString *)cleanupSlicePath ignoreSuffixes:(NSArray *)ignoreSuffixes
{
	NSString *currentSlice = self.currentSlice;

	// get current slice path (if current slice exists)
	NSString *currentSlicePath;
	if (currentSlice.length > 0)
		currentSlicePath = [self.slicesDirectory stringByAppendingPathComponent:currentSlice];
	else
		currentSlicePath = nil;

	// migrate/delete current app data to current slice path
	FolderMigrator *migrator = [[FolderMigrator alloc] initWithSourcePath:self.workingDirectory destinationPath:currentSlicePath];
	migrator.ignoreSuffixes = ignoreSuffixes;
	return [migrator executeMigration];
}

- (BOOL)onlyOneComponent:(NSString *)name
{
	NSArray *pathComponents = [name pathComponents];
	return [pathComponents count] == 1;
}

- (BOOL)switchToSlice:(NSString *)targetSliceName ignoreSuffixes:(NSArray *)ignoreSuffixes
{
	// make sure they give us a target slice
	if (targetSliceName.length < 1)
		return NO;

	// see if we're already on the slice
	NSString *currentSlice = self.currentSlice;
	if ([currentSlice isEqualToString:targetSliceName])
		return YES;

	// cleanup current slice
	if (currentSlice.length > 0)
	{
		NSString *currentSlicePath = [self.slicesDirectory stringByAppendingPathComponent:currentSlice];
		[self cleanupMainDirectoryWithTargetSlicePath:currentSlicePath ignoreSuffixes:ignoreSuffixes];
	}
	
	// migrate new slice data into app directory
	NSString *targetSlicePath = [self.slicesDirectory stringByAppendingPathComponent:targetSliceName];
	FolderMigrator *migrator = [[FolderMigrator alloc] initWithSourcePath:targetSlicePath destinationPath:self.workingDirectory];
	BOOL success = [migrator executeMigration];

	// update current slice (if successful)
	if (success)
		self.currentSlice = targetSliceName;

	return success;
}

- (BOOL)createSlice:(NSString *)newSliceName ignoreSuffixes:(NSArray *)ignoreSuffixes
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
	
	NSString *currentSlice = self.currentSlice;
	if (currentSlice.length < 1)
	{
		self.currentSlice = newSliceName;
		return YES;
	}
	
	// cleanup current slice
	NSString *currentSlicePath = [self.slicesDirectory stringByAppendingPathComponent:currentSlice];
	[self cleanupMainDirectoryWithTargetSlicePath:currentSlicePath ignoreSuffixes:ignoreSuffixes];
	
	// update current slice
	self.currentSlice = newSliceName;

	return YES;
}

- (BOOL)deleteSlice:(NSString *)sliceName ignoreSuffixes:(NSArray *)ignoreSuffixes
{
	// check for invalid name
	if (![self onlyOneComponent:sliceName])
		return NO;

	// if current slice, cleanup app directory
	NSString *currentSlice = self.currentSlice;
	if ([sliceName isEqualToString:currentSlice])
		[self cleanupMainDirectoryWithTargetSlicePath:nil ignoreSuffixes:ignoreSuffixes];
	
	// remove slice directory
	NSString *slicePath = [self.slicesDirectory stringByAppendingPathComponent:sliceName];
	if (![[NSFileManager defaultManager] removeItemAtPath:slicePath error:NULL])
		return NO;
	
	NSArray *slices = self.slices;

	// update current slice
	if ([currentSlice isEqualToString:sliceName] && slices.count > 0)
	{
		self.currentSlice = nil;
		[self switchToSlice:slices[0] ignoreSuffixes:ignoreSuffixes];
	}

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
	
	return YES;
}
@end
