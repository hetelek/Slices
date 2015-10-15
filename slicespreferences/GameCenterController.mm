#import "GameCenterController.h"

@interface GameCenterController ()
@property NSString *appleID;
@property NSString *password;

- (PSTextFieldSpecifier *)appleIDSpecifier;
- (PSTextFieldSpecifier *)passwordSpecifier;
- (PSSpecifier *)addAccountButtonSpecifier;
- (BOOL)shouldAllowAddAccount;
@end

@implementation GameCenterController
- (NSArray *)specifiers
{
	if (!_specifiers)
	{
		_specifiers = [[NSMutableArray alloc] init];

		// account group specifier
		PSSpecifier *accountGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Accounts" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		//[accountGroupSpecifier.properties setValue:@"" forKey:@"footerText"];
		[_specifiers addObject:accountGroupSpecifier];

		// create the specifiers
		NSArray *accounts = [GameCenterAccountManager sharedInstance].accounts;
		for (NSString *account in accounts)
		{
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:account target:self set:nil get:nil detail:nil cell:PSListItemCell edit:nil];
			[specifier setProperty:NSStringFromSelector(@selector(removedSpecifier:)) forKey:PSDeletionActionKey];
			[_specifiers addObject:specifier];
		}

		// if there aren't any slices, tell them
		if (accounts.count < 1)
		{
			[_specifiers addObject:[PSSpecifier preferenceSpecifierNamed:@"No Accounts" target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
			[self setEditingButtonHidden:YES animated:NO];
		}
		else
			[self setEditingButtonHidden:NO animated:YES];

		// create "New Account" group
		PSSpecifier *addAccountGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"New Account" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[_specifiers addObject:addAccountGroupSpecifier];

		// add login fields
		[_specifiers addObject:[self appleIDSpecifier]];
		[_specifiers addObject:[self passwordSpecifier]];

		// add spacer and footer text
		PSSpecifier *emptyGroup = [PSSpecifier emptyGroupSpecifier];
		[emptyGroup.properties setValue:@"Sign in to a Game Center account." forKey:@"footerText"];
		[_specifiers addObject:emptyGroup];

		// add "Add Account" button
		[_specifiers addObject:[self addAccountButtonSpecifier]];

		// localize all the strings
		NSBundle *bundle = [NSBundle bundleWithPath:@"/Library/Application Support/Slices/Slices.bundle"];
		for (PSSpecifier *specifier in _specifiers)
		{
			NSString *footerTextValue = [specifier propertyForKey:@"footerText"];
			if (footerTextValue)
				[specifier setProperty:Localize(footerTextValue) forKey:@"footerText"];

			NSString *name = specifier.name; // "label" key in plist
			if (name)
				specifier.name = Localize(name);
		}
	}

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
				[editableCell.textField setReturnKeyType:UIReturnKeyDone];
			else if ([identifier isEqualToString:APPLE_ID_SPECIFIER_IDENTIFIER])
				[editableCell.textField setReturnKeyType:UIReturnKeyNext];
		}
	}

	return cell;
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

	// reload specifiers the view completely if there are 0 accounts (else it's just removed)
	if ([GameCenterAccountManager sharedInstance].accounts.count < 1)
	{
		PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"No Accounts" target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
		[self insertSpecifier:specifier atIndex:1 animated:YES];
		[self setEditingButtonHidden:YES animated:YES];
	}
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
		if (error)
		{
			NSString *message;
			NSString *title;

			if ([error.domain isEqualToString:GKErrorDomain])
			{
				// connected to server
				if (error.code != GKErrorInvalidCredentials)
				{
					if (error.code != GKErrorNotAuthenticated)
					{
						title = @"Unable to Connect";
						message = @"Unable to connect to server for unknown reasons.";
					}
					else
					{
						title = @"Sign In Failed";
						message = @"Sign in failed for unknown reason. Possible password change?";
					}
				}
				else
				{
					title = @"Invalid credentials";
					message = @"Sign in failed: invalid credentials.";
				}
			}
			else
			{
				title = @"Unable to Connect";
				message = @"Unable to connect to server.";
			}

			UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:title
				message:message
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
						message:[NSString stringWithFormat:@"Failed while adding account to keychain!"]
						delegate:nil
						cancelButtonTitle:@"OK"
						otherButtonTitles:nil];
					[alert show];
				}

				// clear fields
				self.appleID = @"";
				self.password = @"";

				// reload specifiers
				[self reloadSpecifiers];				
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc]
					initWithTitle:@"Unkown Error"
					message:@"Unkown error occurred: use not authenticated."
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
