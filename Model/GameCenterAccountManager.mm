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
	// add the account to the keychain
	return [SSKeychain setPassword:password forService:GAME_CENTER_ACCOUNT_SERVICE account:username];
}

- (BOOL)deleteAccount:(NSString *)username
{
	// remove account from keychain
	return [SSKeychain deletePasswordForService:GAME_CENTER_ACCOUNT_SERVICE account:username];
}

- (void)switchToAccount:(NSString *)username completionHandler:(void (^)(BOOL))completionHandler
{
	// get account proxy
	Class GKDaemonProxyClass = objc_getClass("GKDaemonProxy");
	id<GKAccountServicePrivate> accountServicePrivateProxy = [GKDaemonProxyClass accountServicePrivateProxy];

	// get corresponding password
	NSString *password = [SSKeychain passwordForService:GAME_CENTER_ACCOUNT_SERVICE account:username];

	// sign out current player, then try and sign in
	[accountServicePrivateProxy signOutPlayerWithHandler:^(NSError *error) {
		[accountServicePrivateProxy authenticatePlayerWithUsername:username password:password usingFastPath:true handler:^(GKAuthenticateResponse *response, NSError *error) {
				if (error == nil && [GKLocalPlayer localPlayer].isAuthenticated)
				{
					// authenticated player
					if (completionHandler)
						completionHandler(YES);
				}
				else if (completionHandler)
					completionHandler(NO);
			}];
	}];
}
@end