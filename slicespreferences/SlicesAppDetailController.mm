#import "SlicesAppDetailController.h"

extern NSString* PSDeletionActionKey;

@interface UIPreferencesTable
- (void)reloadData;
@end

@interface SlicesAppDetailController () // PSEditableListController : PSListController
{
	Slicer *_slicer;
	PSSpecifier *_defaultSpecifier;
}

- (void)reloadSpecifiers;
@end

@implementation SlicesAppDetailController
- (id)specifiers
{
	if(_specifiers == nil)
		[self reloadSpecifiers];

	return _specifiers;
}

- (void)reloadSpecifiers
{
	// create a slicer
	if (!_slicer)
	{
		NSString *displayIdentifier = self.specifier.properties[@"displayIdentifier"];
		_slicer = [[Slicer alloc] initWithDisplayIdentifier:displayIdentifier];
	}

	// create a temporary specifiers array (mutable)
	NSMutableArray *specifiers = [[NSMutableArray alloc] init];

	// general group specifier
	PSSpecifier *generalGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"General" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
	[generalGroupSpecifier.properties setValue:@"If the Ask on Touch switch is enabled, you will be asked which slice to use when tapping the application's icon on the homescreen.\n\nIf it's disabled, the application will start with the specified Default Slice." forKey:@"footerText"];
	[specifiers addObject:generalGroupSpecifier];

	// app-specific switch specifier
	PSSpecifier *appSpecificSwitchSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Ask on Touch" target:self set:@selector(setAppSpecificAsk:forSpecifier:) get:@selector(getAppSpecificAsk:) detail:nil cell:PSSwitchCell edit:nil];
	[specifiers addObject:appSpecificSwitchSpecifier];

	// default list specifier
	_defaultSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Default Slice" target:self set:@selector(setDefaultSlice:forSpecifier:) get:@selector(getDefaultSlice:) detail:[PSListItemsController class] cell:PSLinkListCell edit:nil];
	[_defaultSpecifier.properties setValue:@"valuesSource:" forKey:@"valuesDataSource"];
	[_defaultSpecifier.properties setValue:@"titlesSource:" forKey:@"titlesDataSource"];
	[_defaultSpecifier.properties setValue:@"default" forKey:@"Default"]; //forKey:@"The selected slice will be the slice that is launched if the always ask option is disabled."];
	[specifiers addObject:_defaultSpecifier];

	// slices group specifier
	PSSpecifier *slicesGroupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Slices" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
	[slicesGroupSpecifier.properties setValue:@"Deleting a slice will delete all the data associated with it." forKey:@"footerText"];
	[specifiers addObject:slicesGroupSpecifier];

	// create the specifiers
	NSArray *slices = _slicer.slices;
	for (NSString *slice in slices)
	{
		PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:slice target:self set:nil get:nil detail:nil cell:PSListItemCell edit:nil];
		[specifier setProperty:NSStringFromSelector(@selector(removedSpecifier:)) forKey:PSDeletionActionKey];
		[specifiers addObject:specifier];
	}

	// if there aren't any slices, tell them
	if (slices.count < 1)
	{
		[specifiers addObject:[PSSpecifier preferenceSpecifierNamed:@"No Slices" target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
		[self setEditingButtonHidden:YES animated:NO];
	}

	// update the specifier ivar (immutable)
	_specifiers = [specifiers copy];
}

- (void)setDefaultSlice:(NSString *)sliceName forSpecifier:(PSSpecifier*)specifier
{
	_slicer.defaultSlice = sliceName;
}

- (NSString *)getDefaultSlice:(PSSpecifier *)specifier
{
	NSString *defaultSlice = _slicer.defaultSlice;
	if (defaultSlice)
		return defaultSlice;

	return @"Default";
}

- (void)setAppSpecificAsk:(NSNumber *)askNumber forSpecifier:(PSSpecifier*)specifier
{
	_slicer.askOnTouch = [askNumber boolValue];
}

- (NSNumber *)getAppSpecificAsk:(PSSpecifier *)specifier
{
	return [NSNumber numberWithBool:_slicer.askOnTouch];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)canEditRowAtIndexPath
{
	int index = [self indexForIndexPath:canEditRowAtIndexPath];
	PSSpecifier *specifier = _specifiers[index];
	return specifier->cellType == PSListItemCell;
}

- (void)removedSpecifier:(PSSpecifier *)specifier
{
	[_slicer deleteSlice:specifier.name];
	[_defaultSpecifier loadValuesAndTitlesFromDataSource];
	[self reloadSpecifiers];
	[[self table] reloadData];
}

- (NSArray *)titlesSource:(id)target
{
	NSArray *slices = _slicer.slices;
	if (slices.count < 1)
		return @[ @"Default" ];
	return slices;
}

- (NSArray *)valuesSource:(id)target
{
	NSArray *slices = _slicer.slices;
	if (slices.count < 1)
		return @[ @"Default" ];
	return slices;
}
@end
