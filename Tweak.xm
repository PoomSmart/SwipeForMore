#import "Header.h"

static inline NSString *UCLocalizeEx(NSString *key, NSString *value = nil)
{
	return [[NSBundle mainBundle] localizedStringForKey:key value:value table:nil];
}
#define UCLocalize(key) UCLocalizeEx(@ key)

BOOL enabled;
BOOL noConfirm;
BOOL should;
BOOL queue;
BOOL isQueuing;

CFStringRef PreferencesNotification = CFSTR("com.PS.SwipeForMore.prefs");

static void prefs()
{
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.SwipeForMore.plist"];
	id val = prefs[@"enabled"];
	enabled = val ? [val boolValue] : YES;
	val = prefs[@"confirm"];
	noConfirm = [val boolValue];
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	prefs();
}

/*ConfirmationController *cc;

%hook ConfirmationController

- (id)initWithDatabase:(Database *)database
{
	self = %orig;
	cc = self;
	return self;
}

%end*/

%hook Cydia

- (void)reloadDataWithInvocation:(NSInvocation *)invocation { %orig; isQueuing = NO; }
- (void)confirmWithNavigationController:(UINavigationController *)navigation { isQueuing = NO; %orig; }
- (void)cancelAndClear:(bool)clear { isQueuing = clear ? NO : YES; %orig; }

%end

%hook CydiaTabBarController

- (void)presentModalViewController:(UINavigationController *)controller animated:(BOOL)animated
{
	%orig;
	if ([controller.topViewController isKindOfClass:NSClassFromString(@"ConfirmationController")]) {
		if (should && !isQueuing)
			[(ConfirmationController *)controller.topViewController complete];
		else if (queue) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
				[(ConfirmationController *)controller.topViewController _doContinue];
				queue = NO;
			});
		}
	}
}

%end

static _finline void _UpdateExternalStatus(uint64_t newStatus) {
    int notify_token;
    if (notify_register_check("com.saurik.Cydia.status", &notify_token) == NOTIFY_STATUS_OK) {
        notify_set_state(notify_token, newStatus);
        notify_cancel(notify_token);
    }
    notify_post("com.saurik.Cydia.status");
}

%hook ProgressController

- (void)invoke:(NSInvocation *)invocation withTitle:(NSString *)title
{
	%orig;
	if (should) {
		should = NO;
		if (MSHookIvar<unsigned>(self, "cancel_") == 0) {
			Cydia *delegate = (Cydia *)[UIApplication sharedApplication];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
				_UpdateExternalStatus(0);
				[delegate returnToCydia];
				[[[self navigationController] parentOrPresentingViewController] dismissModalViewControllerAnimated:YES];
			});
		}
	}
}

%end

%hook FilteredPackageListController

%new
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

%new
- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath_
{
	Package *package = [self packageAtIndexPath:indexPath_];
	Cydia *delegate = (Cydia *)[UIApplication sharedApplication];
	if ([delegate class] != NSClassFromString(@"Cydia"))
		return nil;
	NSMutableArray *actions = [NSMutableArray array];
	BOOL installed = ![package uninstalled];
	BOOL upgradable = [package upgradableAndEssential:NO];
	if (installed) {
		UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:UCLocalize("REMOVE") handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			should = noConfirm;
			[delegate removePackage:package];
		}];
		[actions addObject:deleteAction];
	}
	NSString *installTitle = installed ? (upgradable ? UCLocalize("UPGRADE") : UCLocalize("REINSTALL")) : UCLocalize("INSTALL");
	UITableViewRowAction *installAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:installTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
		should = noConfirm;
		[delegate installPackage:package];
	}];
	installAction.backgroundColor = [UIColor systemBlueColor];
	[actions addObject:installAction];
	if ([package mode] != nil) {
		UITableViewRowAction *clearAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:UCLocalize("CLEAR") handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
			should = noConfirm;
			[delegate clearPackage:package];
		}];
		clearAction.backgroundColor = [UIColor grayColor];
		[actions addObject:clearAction];
	} else {
		NSString *queueTitle = [NSString stringWithFormat:@"%@\n(%@)", UCLocalize("QUEUE"), (installed ? UCLocalize("REMOVE") : UCLocalize("INSTALL"))];
		UITableViewRowAction *queueAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:queueTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
			should = NO;
			queue = YES;
			if (installed)
				[delegate removePackage:package];
			else
				[delegate installPackage:package];
		}];
		queueAction.backgroundColor = installed ? [UIColor systemYellowColor] : [UIColor systemGreenColor];
		[actions addObject:queueAction];
	}
    return actions;
}

%new
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
}

%end

%ctor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	prefs();
	if (enabled) {
		%init;
	}
}