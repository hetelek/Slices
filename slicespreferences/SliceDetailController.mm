#import "SliceDetailController.h"

@interface SliceDetailController ()
@property Slicer *slicer;
@property NSString *sliceName;

- (PSTextFieldSpecifier *)nameSpecifier;
@end

@implementation SliceDetailController
- (id)specifiers
{
	self.sliceName = self.specifier.name;
	self.slicer = self.specifier.properties[@"slicer"];

	if (self.sliceName && self.slicer)
	{
		if(!_specifiers)
		{
			_specifiers = [[NSMutableArray alloc] init];

			// slice name group specifier
			PSSpecifier *sliceNameGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Slice Name" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
			[_specifiers addObject:sliceNameGroupSpecifier];

			// add name specifier (text box)
			[_specifiers addObject:[self nameSpecifier]];

			// game center account group specifier
			PSSpecifier *gameCenterAccountGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Game Center Account" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
			[gameCenterAccountGroupSpecifier.properties setValue:@"Select which Game Center account to use with this slice." forKey:@"footerText"];

			[gameCenterAccountGroupSpecifier setProperty:[NSNumber numberWithBool:YES] forKey:PSIsRadioGroupKey];
			[_specifiers addObject:gameCenterAccountGroupSpecifier];

			// default list specifier
			PSSpecifier *gameCenterAccountSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Account" target:self set:@selector(setGameCenterAccount:forSpecifier:) get:@selector(getGameCenterAccount:) detail:[PSListItemsController class] cell:PSLinkListCell edit:nil];
			[gameCenterAccountSpecifier.properties setValue:@"valuesSource:" forKey:@"valuesDataSource"];
			[gameCenterAccountSpecifier.properties setValue:@"valuesSource:" forKey:@"titlesDataSource"];
			[_specifiers addObject:gameCenterAccountSpecifier];
		}
	}

	return _specifiers;
}

- (void)setGameCenterAccount:(NSString *)gameCenterAccount forSpecifier:(PSSpecifier*)specifier
{
	[self.slicer setGameCenterAccount:gameCenterAccount forSlice:self.sliceName];
}

- (NSString *)getGameCenterAccount:(PSSpecifier *)specifier
{
	NSString *gameCenterAccount = [self.slicer gameCenterAccountForSlice:self.sliceName];
	if (gameCenterAccount)
		return gameCenterAccount;

	return Localize(@"None");
}

- (NSArray *)valuesSource:(id)target
{
	NSMutableArray *accountsFinal = [[NSMutableArray alloc] init];
	[accountsFinal addObject:Localize(@"None")];

	NSArray *accounts = [GameCenterAccountManager sharedInstance].accounts;
	[accountsFinal addObjectsFromArray:accounts];

	return accountsFinal;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

	// if the cell is an editable cell, it's either the apple id or password cell
	if ([cell isKindOfClass:objc_getClass("PSEditableTableCell")])
	{
		PSEditableTableCell *editableCell = (PSEditableTableCell *)cell;
		if (editableCell.textField)
		{
			// "Done" key for password field, "Next" key for Apple ID field
			NSString *identifier = editableCell.specifier.identifier;
			if ([identifier isEqualToString:NAME_SPECIFIER_IDENTIFIER])
				[editableCell.textField setReturnKeyType:UIReturnKeyDone];
		}
	}

	return cell;
}

- (void)renameSlice:(NSString *)newSliceName withSpecifier:(PSSpecifier *)specifier
{
	NSString *originalSliceName = self.sliceName;
	NSString *targetSliceName = newSliceName;

	if ([self.slicer renameSlice:originalSliceName toName:targetSliceName])
	{
		self.sliceName = targetSliceName;
		self.navigationItem.title = targetSliceName;
		self.specifier.name = targetSliceName;
	}
}

- (PSTextFieldSpecifier *)nameSpecifier
{
	PSTextFieldSpecifier *specifier = [PSTextFieldSpecifier preferenceSpecifierNamed:@"" target:self set:@selector(renameSlice:withSpecifier:) get:@selector(sliceName) detail:nil cell:PSEditTextCell edit:nil];

	// setup properties
	[specifier setProperty:NAME_SPECIFIER_IDENTIFIER forKey:PSKeyNameKey];
	specifier.identifier = NAME_SPECIFIER_IDENTIFIER;
	[specifier setKeyboardType:UIKeyboardTypeASCIICapable autoCaps:NO autoCorrection:UITextAutocorrectionTypeDefault];

	// set placeholder text
	[specifier setPlaceholder:@"Name"];

	// set cell's class
	[specifier setProperty:[SlicesEditableTableCell class] forKey:PSCellClassKey];

	return specifier;
}

- (BOOL)canBeShownFromSuspendedState
{
	return NO;
}
@end
