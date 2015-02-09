#import "RawSlicer.h"

@interface AppGroupSlicer : RawSlicer
/*
	APP GROUP DIRECTORY LAYOUT

	Library/
		Preferences/
		Caches/
	.com.apple.mobile_container_manager.metadata.plist
*/

- (BOOL)switchToSlice:(NSString *)targetSliceName;
- (BOOL)createSlice:(NSString *)newSliceName;
- (BOOL)deleteSlice:(NSString *)sliceName;
@end
