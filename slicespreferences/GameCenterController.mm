#import "GameCenterController.h"

@interface GameCenterController ()
@property NSString *appleID;
@property NSString *password;

- (PSTextFieldSpecifier *)appleIDSpecifier;
- (PSTextFieldSpecifier *)passwordSpecifier;
- (PSSpecifier *)addAccountButtonSpecifier;
- (BOOL)shouldAllowAddAccount;
- (void)refreshView;
@end

@implementation GameCenterController
- (id)specifiers
{
	if(_specifiers == nil)
		[self reloadSpecifiers];

	return _specifiers;
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
			if ([identifier isEqualToString:PASSWORD_SPECIFIER_IDENTIFIER])
			{
				[editableCell.textField setReturnKeyType:UIReturnKeyDone];
			}
			else if ([identifier isEqualToString:APPLE_ID_SPECIFIER_IDENTIFIER])
			{
				[editableCell.textField setReturnKeyType:UIReturnKeyNext];
			}
		}
	}

	return cell;
}

- (void)reloadSpecifiers
{
	// create a temporary specifiers array (mutable)
	NSMutableArray *specifiers = [[NSMutableArray alloc] init];

	// account group specifier
	PSSpecifier *accountGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Accounts" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
	//[accountGroupSpecifier.properties setValue:@"If the Ask on Touch switch is enabled, you will be asked which slice to use when tapping the application's icon on the homescreen.\n\nIf it's disabled, the application will start with the specified Default Slice." forKey:@"footerText"];
	[specifiers addObject:accountGroupSpecifier];

	// create the specifiers
	NSArray *accounts = [GameCenterAccountManager sharedInstance].accounts;
	for (NSString *account in accounts)
	{
		PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:account target:self set:nil get:nil detail:nil cell:PSListItemCell edit:nil];
		//specifier->action = @selector(renameSlice:);
		[specifier setProperty:NSStringFromSelector(@selector(removedSpecifier:)) forKey:PSDeletionActionKey];
		[specifiers addObject:specifier];
	}

	// if there aren't any slices, tell them
	if (accounts.count < 1)
	{
		[specifiers addObject:[PSSpecifier preferenceSpecifierNamed:@"No Accounts" target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
		[self setEditingButtonHidden:YES animated:NO];
	}
	else
		[self setEditingButtonHidden:NO animated:YES];

	// create "New Account" group
	PSSpecifier *addAccountGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"New Account" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
	[specifiers addObject:addAccountGroupSpecifier];

	// add login fields
	[specifiers addObject:[self appleIDSpecifier]];
	[specifiers addObject:[self passwordSpecifier]];

	// add spacer and footer text
	PSSpecifier *emptyGroup = [PSSpecifier emptyGroupSpecifier];
	[emptyGroup.properties setValue:@"Sign in to a Game Center account." forKey:@"footerText"];
	[specifiers addObject:emptyGroup];

	// add "Add Account" button
	[specifiers addObject:[self addAccountButtonSpecifier]];

	// localize all the strings
	NSBundle *bundle = [NSBundle bundleWithPath:@"/Library/Application Support/Slices/Slices.bundle"];
	for (PSSpecifier *specifier in specifiers)
	{
		NSString *footerTextValue = [specifier propertyForKey:@"footerText"];
		if (footerTextValue)
			[specifier setProperty:Localize(footerTextValue) forKey:@"footerText"];

		NSString *name = specifier.name; // "label" key in plist
		if (name)
			specifier.name = Localize(name);
	}

	// update the specifier ivar (immutable)
	_specifiers = [specifiers copy];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)canEditRowAtIndexPath
{
	int index = [self indexForIndexPath:canEditRowAtIndexPath];
	PSSpecifier *specifier = _specifiers[index];
	return specifier->cellType == PSListItemCell;
}

- (void)removedSpecifier:(PSSpecifier *)specifier
{
	// delete the account
	[[GameCenterAccountManager sharedInstance] deleteAccount:specifier.name];

	// refresh the view completely if there are 0 accounts (else it's just removed)
	if ([GameCenterAccountManager sharedInstance].accounts.count < 1)
		[self refreshView];
}

- (void)refreshView
{
	[self reloadSpecifiers];
	[self reload];
}

- (BOOL)canBeShownFromSuspendedState
{
	return NO;
}

- (void)setPassword:(NSString *)password withSpecifier:(PSSpecifier *)specifier
{
	self.password = password;
}

- (void)setAppleID:(NSString *)appleID withSpecifier:(PSSpecifier *)specifier
{
	self.appleID = appleID;
}

- (void)addAccountButtonTapped:(id)sender
{
	// this needs to be done becuase the setter isn't called first if the "Done" button is tapped
	if ([sender isKindOfClass:[UITextField class]])
		self.password = [sender text];

	// make sure they're allowed (no null fields)
	if (![self shouldAllowAddAccount])
		return;

	// don't allow them to interact during sign in
	self.view.userInteractionEnabled = NO;

	// close the keyboard
	[[[self table] firstResponder] resignFirstResponder];

	// get the account proxy
	Class GKDaemonProxyClass = objc_getClass("GKDaemonProxy");
	id<GKAccountServicePrivate> accountServicePrivateProxy = [GKDaemonProxyClass accountServicePrivateProxy];

	// attempt to authenticate
	[accountServicePrivateProxy authenticatePlayerWithUsername:self.appleID password:self.password usingFastPath:true handler:^(GKAuthenticateResponse *response, NSError *error) {
		// allow user interaction
		self.view.userInteractionEnabled = YES;

		// if there was an error, tell them
		if (error != nil)
		{
			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:@"Failed"
				message:[NSString stringWithFormat:@"Failed to authenticate: %@", error]
				delegate:nil
				cancelButtonTitle:@"OK"
				otherButtonTitles:nil];
			[alert show];
		}
		else
		{
			// see if they successfully authenticated
			if ([GKLocalPlayer localPlayer].isAuthenticated)
			{
				// add the account to the list
				if (![[GameCenterAccountManager sharedInstance] addAccount:self.appleID password:self.password])
				{
					UIAlertView *alert = [[UIAlertView alloc]
						initWithTitle:@"Failed"
						message:[NSString stringWithFormat:@"Failed adding account to keychain!"]
						delegate:nil
						cancelButtonTitle:@"OK"
						otherButtonTitles:nil];
					[alert show];
				}

				// clear fields
				self.appleID = @"";
				self.password = @"";

				// refresh view
				[self refreshView];				
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc]
					initWithTitle:@"Invalid"
					message:[NSString stringWithFormat:@"Invalid credentials."]
					delegate:nil
					cancelButtonTitle:@"OK"
					otherButtonTitles:nil];
				[alert show];
			}
		}
	}];
}

- (PSSpecifier *)addAccountButtonSpecifier
{
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"Add Account" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];

	specifier.buttonAction = @selector(addAccountButtonTapped:);
	specifier.identifier = ADD_ACCOUNT_SPECIFIER_IDENTIFIER;

	return specifier;
}

- (PSTextFieldSpecifier *)appleIDSpecifier
{
	PSTextFieldSpecifier *specifier = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Apple ID" target:self set:@selector(setAppleID:withSpecifier:) get:nil detail:nil cell:PSEditTextCell edit:nil];

	// setup properties
	[specifier setProperty:APPLE_ID_SPECIFIER_IDENTIFIER forKey:PSKeyNameKey];
	specifier.identifier = APPLE_ID_SPECIFIER_IDENTIFIER;
	[specifier setKeyboardType:UIKeyboardTypeEmailAddress autoCaps:NO autoCorrection:UITextAutocorrectionTypeDefault];

	// set placeholder text
	[specifier setPlaceholder:@"name@example.com"];

	// set cell's class
	[specifier setProperty:[SlicesEditableTableCell class] forKey:PSCellClassKey];

	return specifier;
}

- (PSTextFieldSpecifier *)passwordSpecifier
{
	PSTextFieldSpecifier *specifier = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Password" target:self set:@selector(setPassword:withSpecifier:) get:nil detail:nil cell:PSSecureEditTextCell edit:nil];

	// setup properties
	[specifier setProperty:PASSWORD_SPECIFIER_IDENTIFIER forKey:PSKeyNameKey];
	specifier.buttonAction = @selector(addAccountButtonTapped:);
	specifier.identifier = PASSWORD_SPECIFIER_IDENTIFIER;
	[specifier setKeyboardType:UIKeyboardTypeDefault autoCaps:NO autoCorrection:UITextAutocorrectionTypeDefault];

	// set placeholder text
	[specifier setPlaceholder:@"Required"];

	// set cell's class
	[specifier setProperty:[SlicesEditableTableCell class] forKey:PSCellClassKey];

	return specifier;
}

- (BOOL)shouldAllowAddAccount
{
	return self.appleID.length > 0 && self.password.length > 0;
}
@end
