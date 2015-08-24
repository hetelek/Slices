#import <UIKit/UIKit.h>

#import <Braintree/Braintree.h>

@interface ViewController : UIViewController <BTDropInViewControllerDelegate>

@property (nonatomic, strong) Braintree *braintree;

@end
