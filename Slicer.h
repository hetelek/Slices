#import <UIKit/UIKit.h>
#import <AppList/AppList.h>
#import <substrate.h>
#import "SpringBoardHeaders.h"

@interface SBIconView (New)
@property (readonly) SBApplication *application;

- (void)killApplication;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
@end

@interface Slicer : NSObject
@property (readonly) NSArray *slices;
@property (nonatomic) NSString *defaultSlice;
@property (nonatomic) BOOL askOnTouch;
@property (nonatomic) NSString *currentSlice;

- (instancetype)initWithDisplayIdentifier:(NSString *)displayIdentifier;
- (instancetype)initWithApplication:(SBApplication *)application;
- (BOOL)switchToSlice:(NSString *)sliceName;
- (BOOL)createSlice:(NSString *)sliceName;
- (BOOL)deleteSlice:(NSString *)sliceName;
- (BOOL)renameSlice:(NSString *)originaSliceName toName:(NSString *)targetSliceName;
@end
