#import "Expetelek.h"

@implementation Expetelek
static NSDate *lastCheck = nil;
static BOOL alreadyVerified = NO;

extern "C" CFPropertyListRef MGCopyAnswer(CFStringRef property);

+ (NSDate *)lastChecked
{
	return lastCheck;
}

+ (BOOL)alreadyVerified
{
	return alreadyVerified;
}

static NSString *UniqueIdentifier()
{
	return (__bridge NSString *)MGCopyAnswer(CFSTR("UniqueDeviceID"));
}

+ (void)checkLicense:(NSString *)package vendor:(NSString *)vendor completionHandler:(void(^)(BOOL licensed, BOOL parseable, NSString *response))handler
{
	if (alreadyVerified)
	{
		handler(YES, YES, @"1");
		return;
	}
	
	if (lastCheck)
	{
		NSTimeInterval timeInterval = [lastCheck timeIntervalSinceNow];
		if (-kMinimumSecondsToWait < timeInterval)
			return;
	}
	lastCheck = [NSDate date];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSString *uuid = UniqueIdentifier();
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://cydia.expetelek.com/check.php?vendor=%@&package=%@&uuid=%@", vendor, package, uuid]];
		NSString *response = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
		
		bool parseable = YES;
		bool licensed;
		if ([response isEqualToString:@"1"])
		{
			licensed = YES;
			alreadyVerified = YES;
		}
		else if ([response isEqualToString:@"0"])
			licensed = NO;
		else
		{
			licensed = NO;
			parseable = NO;
		}
		
		handler(licensed, parseable, response);
	});
}

@end
