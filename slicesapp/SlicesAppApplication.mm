#import "RootViewController.h"

@interface SlicesAppApplication : UIApplication <UIApplicationDelegate>
@property (nonatomic, retain) RootViewController *viewController;
@property (nonatomic, retain) UIWindow *window;
@end

@implementation SlicesAppApplication
- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.viewController = [[RootViewController alloc] init];
	[self.window addSubview:self.viewController.view];
	[self.window makeKeyAndVisible];
}
@end
