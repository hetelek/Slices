#import "SlicesEditableTableCell.h"

@implementation SlicesEditableTableCell
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	id target = self.specifier.target;
	SEL action = self.specifier.buttonAction;

	if (action)
	{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[target performSelector:action withObject:textField];
#pragma clang diagnostic pop
	}

	return [self.specifier.identifier isEqualToString:PASSWORD_SPECIFIER_IDENTIFIER];
}
@end
