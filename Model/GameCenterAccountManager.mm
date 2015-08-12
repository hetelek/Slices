#import "GameCenterAccountManager.h"

@implementation GameCenterAccountManager
+ (GameCenterAccountManager *)sharedInstance
{
	static dispatch_once_t p = 0;
     
	__strong static id _sharedObject = nil;
     
	dispatch_once(&p, ^{
		_sharedObject = [[self alloc] init];
	});

    return _sharedObject;
}

- (NSArray *)accounts
{
	// get accounts
	NSArray *accountDictionaries = [SSKeychain accountsForService:GAME_CENTER_ACCOUNT_SERVICE];

	// get the account names
	NSMutableArray *accounts = [[NSMutableArray alloc] init];
	for (NSDictionary *accountDictionary in accountDictionaries)
		[accounts addObject:accountDictionary[@"acct"]];

	return accounts;
}

- (BOOL)addAccount:(NSString *)username password:(NSString *)password
{
	return [SSKeychain setPassword:password forService:GAME_CENTER_ACCOUNT_SERVICE account:username];
}

- (BOOL)deleteAccount:(NSString *)username
{
	return [SSKeychain deletePasswordForService:GAME_CENTER_ACCOUNT_SERVICE account:username];
}

- (void)switchToAccount:(NSString *)username
{
	Class GKDaemonProxyClass = objc_getClass("GKDaemonProxy");
	id<GKAccountServicePrivate> accountServicePrivateProxy = [GKDaemonProxyClass accountServicePrivateProxy];

	NSString *password = [SSKeychain passwordForService:GAME_CENTER_ACCOUNT_SERVICE account:username];

	[accountServicePrivateProxy signOutPlayerWithHandler:^(NSError *error) {
		if (error)
		{
			NSLog(@"error while signing out: %@", error);
		}

		[accountServicePrivateProxy authenticatePlayerWithUsername:username password:password usingFastPath:true handler:^(GKAuthenticateResponse *response, NSError *error) {
				if (error != nil)
				{
					NSLog(@"error while switching game center accounts: %@", error);
				}
				else
				{
					NSLog(@"name: %@", response.accountName);
					NSLog(@"login disabled: %i", response.loginDisabled);

					if ([GKLocalPlayer localPlayer].isAuthenticated)
					{
						NSLog(@"authenticated player!");
					}
					else
					{
						NSLog(@"hmmmm... failed to authenticate player");
					}
				}
			}];
	}];
}
@end