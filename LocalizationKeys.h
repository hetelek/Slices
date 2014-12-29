#define LocalizeString(key, bundle) [bundle localizedStringForKey:key value:key table:@"Slices"]

#define THANK_YOU_KEY @"Thank you for purchasing Slices! By default, no applications are configured to use Slices. To enable some, visit the Settings."
#define ASK_ON_TOUCH_TEXT_KEY @"If the Ask on Touch switch is enabled, you will be asked which slice to use when tapping the application's icon on the homescreen.\n\nIf it's disabled, the application will start with the specified Default Slice."
#define ASK_ON_TOUCH_HEADER_KEY @"Ask on Touch"
#define DELETING_SLICES_KEY @"Deleting a slice will delete all the data associated with it. To rename a slice, tap it. If no slices exists and you create one, all the existing data will be copied into the new slice."
#define DEFAULT_SLICE_KEY @"Default Slice"
#define GENERAL_KEY @"General"
#define NO_SLICES_KEY @"No Slices"
#define CREATE_SLICE_KEY @"Create Slice"
#define NEW_SLICE_KEY @"New Slice"
#define ENTER_SLICE_NAME_KEY @"Enter the slice name"
#define CANCEL_KEY @"Cancel"
#define RENAME_SLICE_KEY @"Rename Slice"
#define ENTER_NEW_SLICE_NAME_KEY @"Enter the new slice name"
#define DEFAULT_KEY @"Default"
#define APPLICATIONS_KEY @"Applications"
#define DISABLING_KEY @"Disabling will leave all applications set to the last slice they were on."
#define TWITTER_KEY @"@hetelek"
#define ENABLED_STRING_KEY @"Enabled"
#define QUESTIONS_KEY @"If you have any questions or experience any problems, contact hetelek using Twitter or email (through Cydia)."
#define LINKS_KEY @"Links"
#define USER_APPLICATIONS @"User Applications"

static NSBundle *bundle = [NSBundle bundleWithPath:@"/Library/Application Support/Slices/Slices.bundle"];
#define Localize(key) LocalizeString(key, bundle)