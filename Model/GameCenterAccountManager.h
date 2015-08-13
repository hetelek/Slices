#import <objc/runtime.h>
#import <GameKit/GameKit.h>

#import "SSKeychain/SSKeychain.h"

#import "../Headers/GameCenterHeaders.h"

#define GAME_CENTER_ACCOUNT_SERVICE @"GCAccountService"

@interface GameCenterAccountManager : NSObject
@property (nonatomic, readonly) NSArray *accounts;

+ (GameCenterAccountManager *)sharedInstance;

- (BOOL)addAccount:(NSString *)username password:(NSString *)password;
- (void)switchToAccount:(NSString *)username completionHandler:(void (^)(BOOL))completionHandler;
- (BOOL)deleteAccount:(NSString *)username;
@end