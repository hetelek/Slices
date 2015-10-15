@interface GKInternalRepresentation : NSObject
@end

@interface GKAuthenticateResponse : GKInternalRepresentation
@property (nonatomic) BOOL shouldShowLinkAccountsUI;
@property (retain, nonatomic) NSURL *passwordChangeURL;
@property (nonatomic) BOOL passwordChangeRequired;
@property (nonatomic) int environment;
@property (nonatomic) BOOL loginDisabled;
@property (retain, nonatomic) NSString *authToken;
@property (retain, nonatomic) NSString *playerID;
@property (retain, nonatomic) NSString *accountName;
@end


@protocol GKAccountService
- (oneway void)generateIdentityVerificationSignatureWithHandler:(void (^)(NSDictionary *, NSError *))handler;
- (oneway void)authenticatePlayerWithExistingCredentialsWithHandler:(void (^)(GKAuthenticateResponse *, NSError *))handler;
@end

@protocol GKAccountServicePrivate <GKAccountService>
- (oneway void)authenticatePlayerWithUsername:(NSString *)username password:(NSString *)password usingFastPath:(BOOL)fastPath handler:(void (^)(GKAuthenticateResponse *, NSError *))handler;
- (oneway void)signOutPlayerWithHandler:(void (^)(NSError *))handler;
@end

@interface GKDaemonProxy : NSObject
+ (id<GKAccountServicePrivate>)accountServicePrivateProxy;
@end
