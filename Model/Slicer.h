#import <substrate.h>
#import <UIKit/UIKit.h>
#import <AppList/AppList.h>

#import "../Headers/LocalizationKeys.h"
#import "../Headers/SpringBoardHeaders.h"

#import "RawSlicer.h"

#define SLICES_DIRECTORY @"/private/var/mobile/Library/Preferences/Slices/"

@interface SBIconView (New)
@property (readonly) SBApplication *application;

- (void)killApplication;
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
@end

@interface Slicer : RawSlicer
@property (readonly) NSString *displayIdentifier;
@property (nonatomic) NSString *defaultSlice;
@property (nonatomic) BOOL askOnTouch;

- (instancetype)initWithDisplayIdentifier:(NSString *)displayIdentifier;
- (instancetype)initWithApplication:(SBApplication *)application;

- (BOOL)switchToSlice:(NSString *)sliceName;
- (BOOL)createSlice:(NSString *)sliceName;
- (BOOL)deleteSlice:(NSString *)sliceName;
@end
