#import <UIKit/UIKit.h>

@protocol SBIconViewDelegate <NSObject>
@optional
- (void)iconTapped:(id)arg1;
@end

@interface SBApplication : NSObject
@property (readonly) int pid;
@property NSString *displayIdentifier; 

- (NSString *)containerPath;
- (void)resumeToQuit;
@end

@interface SBIcon : NSObject
- (SBApplication *)application;
@end

@interface SBIconView : NSObject <UIActionSheetDelegate>
{
	BOOL _isGrabbed;
	BOOL _touchDownInIcon;
	BOOL _isEditing;
	id<SBIconViewDelegate> _delegate;
}
@property SBIcon *icon; 

- (void)_delegateTouchEnded:(BOOL)ended;
- (BOOL)_delegateTapAllowed;
- (void)setHighlighted:(BOOL)highlighted;
- (void)cancelLongPressTimer;
- (BOOL)allowsTapWhileEditing;
@end

@interface SBAppWindow : UIWindow
- (void)_updateInterfaceOrientationFromDeviceOrientation;
@end

@interface SBUIController
@property SBAppWindow *window;

- (SBUIController *)sharedInstance;
@end