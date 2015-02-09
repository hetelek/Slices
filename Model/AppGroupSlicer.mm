#import "AppGroupSlicer.h"

@implementation AppGroupSlicer
- (BOOL)switchToSlice:(NSString *)targetSliceName
{
	NSArray *IGNORE_SUFFIXES = @[ @".com.apple.mobile_container_manager.metadata.plist" ];
	return [super switchToSlice:targetSliceName ignoreSuffixes:IGNORE_SUFFIXES];
}

- (BOOL)createSlice:(NSString *)newSliceName
{
	NSArray *IGNORE_SUFFIXES = @[ @".com.apple.mobile_container_manager.metadata.plist" ];
	BOOL success = [super createSlice:newSliceName ignoreSuffixes:IGNORE_SUFFIXES];
	if (!success)
		return NO;

	NSFileManager *manager = [NSFileManager defaultManager];
	NSArray *DIRECTORIES = @[ @"Library/Preferences", @"Library/Caches" ];
	for (NSString *directory in DIRECTORIES)
	{
		NSString *currentDirectoryFullPath = [self.workingDirectory stringByAppendingPathComponent:directory];
		if (![manager createDirectoryAtPath:currentDirectoryFullPath withIntermediateDirectories:YES attributes:nil error:NULL])
			success = NO;
	}

	return success;
}

- (BOOL)deleteSlice:(NSString *)sliceName
{
	NSArray *IGNORE_SUFFIXES = @[ @".com.apple.mobile_container_manager.metadata.plist" ];
	return [super deleteSlice:sliceName ignoreSuffixes:IGNORE_SUFFIXES];
}
@end