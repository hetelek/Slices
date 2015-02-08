#import "SliceSetting.h"

@interface SliceSetting ()
@property (readwrite) NSString *prefix;
@end

@implementation SliceSetting
- (instancetype)initWithPrefix:(NSString *)prefix
{
	self = [super init];

	self.prefix = prefix;

	return self;
}

- (NSString *)getValueInDirectory:(NSString *)directory
{
	NSString *fullSettingFileName = [self fullSettingFileNameInDirectory:directory];
	if (fullSettingFileName.length < 1)
		return NULL;

	return [fullSettingFileName substringFromIndex:self.prefix.length];
}

- (BOOL)setValueInDirectory:(NSString *)directory value:(NSString *)value
{
	NSString *newFullSettingFileName = [self.prefix stringByAppendingString:value];
	NSString *newFullSettingFilePath = [directory stringByAppendingPathComponent:newFullSettingFileName];

	// if the directory doesn't exist, create it
	NSFileManager *manager = [NSFileManager defaultManager];
	if (![manager fileExistsAtPath:directory])
		[manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];

	NSString *fullSettingFileName = [self fullSettingFileNameInDirectory:directory];
	if (fullSettingFileName.length > 0)
	{
		NSString *fullSettingFilePath = [directory stringByAppendingPathComponent:fullSettingFileName];
		return [manager moveItemAtPath:fullSettingFilePath toPath:newFullSettingFilePath error:NULL];
	}
	
	return [manager createFileAtPath:newFullSettingFilePath contents:nil attributes:nil];
}

- (NSString *)fullSettingFileNameInDirectory:(NSString *)directory
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSArray *possibleFiles = [manager contentsOfDirectoryAtPath:directory error:NULL];

	for (NSString *possibleFile in possibleFiles)
		if ([possibleFile hasPrefix:self.prefix])
			return possibleFile;

	return NULL;
}
@end