#import <UIKit/UIKit.h>
#import <AppList/AppList.h>
#import "SpringBoardHeaders.h"

@interface Slicer : NSObject
@property (readonly) NSArray *slices;

- (instancetype)initWithDisplayIdentifier:(NSString *)displayIdentifier;
- (BOOL)switchToSlice:(NSString *)sliceName;
- (BOOL)createSlice:(NSString *)sliceName;
- (BOOL)deleteSlice:(NSString *)sliceName;
@end