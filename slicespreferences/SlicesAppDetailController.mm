#import "SlicesAppDetailController.h"

extern NSString* PSDeletionActionKey;

@interface SlicesAppDetailController () // PSEditableListController : PSListController
{
	Slicer *_slicer;
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

	// create group specifier
	PSSpecifier *groupSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Slices" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
	[groupSpecifier.properties setValue:@"Deleting a slice will delete all the data in that slice." forKey:@"footerText"];
	[specifiers addObject:groupSpecifier];

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

- (void)removedSpecifier:(PSSpecifier *)specifier
{
	[_slicer deleteSlice:specifier.name];
	[self reload];
}
@end
