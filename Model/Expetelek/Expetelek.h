#import <UIKit/UIKit.h>

#define kMinimumSecondsToWait 120.0

@interface Expetelek : NSObject

+ (NSDate *)lastChecked;
+ (BOOL)alreadyVerified;

+ (void)checkLicense:(NSString *)package vendor:(NSString *)vendor completionHandler:(void(^)(BOOL licensed, BOOL parseable, NSString *response))handler;

@end
