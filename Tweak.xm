#import "../CydiaHeader.h"
#import <notify.h>

static inline NSString *UCLocalizeEx(NSString *key, NSString *value = nil)
{
	return [[NSBundle mainBundle] localizedStringForKey:key value:value table:nil];
}
#define UCLocalize(key) UCLocalizeEx(@ key)

BOOL enabled;
BOOL noConfirm;
BOOL autoDismiss;
BOOL short_;
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
	val = prefs[@"autoDismiss"];
	autoDismiss = val ? [val boolValue] : YES;
	val = prefs[@"short"];
	short_ = [val boolValue];
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

CYPackageController *cy;

%hook CYPackageController

- (id)initWithDatabase:(Database *)database forPackage:(Package *)package withReferrer:(id)referrer
{
	self = %orig;
	cy = self;
	return self;
}

%end

%hook Cydia

- (void)reloadDataWithInvocation:(NSInvocation *)invocation { %orig; isQueuing = NO; }
- (void)confirmWithNavigationController:(UINavigationController *)navigation { isQueuing = NO; %orig; }
- (void)cancelAndClear:(bool)clear { isQueuing = clear ? NO : YES; %orig; }

%end

%hook CydiaTabBarController

- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion
{
	if ([vc isKindOfClass:[UINavigationController class]]) {
		if ([((UINavigationController *)vc).topViewController class] == NSClassFromString(@"ConfirmationController")) {
			void (^block)(void) = ^(void) {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.16*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
					if (should && !isQueuing)
						[(ConfirmationController *)((UINavigationController *)vc).topViewController confirmButtonClicked];
					else if (queue) {
						[(ConfirmationController *)((UINavigationController *)vc).topViewController _doContinue];
							queue = NO;
					}
				});
			};
			%orig(vc, animated, block);
			return;
		}
	}
	%orig;
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
		uint64_t status = 0;
		int notify_token;
		if (notify_register_check("com.saurik.Cydia.status", &notify_token) == NOTIFY_STATUS_OK) {
			notify_get_state(notify_token, &status);
			notify_cancel(notify_token);
		}
		if (status == 0) {
			Cydia *delegate = (Cydia *)[UIApplication sharedApplication];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.22*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
				_UpdateExternalStatus(0);
				[delegate returnToCydia];
				[[[self navigationController] parentOrPresentingViewController] dismissModalViewControllerAnimated:YES];
			});
		}
	}
}

%end

NSString *itsString(NSString *key, NSString *value)
{
	// ¯\_(ツ)_/¯
	return [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/iTunesStore.framework"] localizedStringForKey:key value:value table:nil];
}

NSString *buyString()
{
	return short_ ? @"💳" : itsString(@"BUY", @"Buy");
}

NSString *installString()
{
	return short_ ? @"↓" : UCLocalize("INSTALL");
}

NSString *reinstallString()
{
	return short_ ? @"↺" : UCLocalize("REINSTALL");
}

NSString *upgradeString()
{
	return short_ ? @"↑" : UCLocalize("UPGRADE");
}

NSString *removeString()
{
	return short_ ? @"╳" : UCLocalize("REMOVE");
}

NSString *queueString()
{
	return short_ ? @"⇟" : UCLocalize("QUEUE");
}

NSString *clearString()
{
	return short_ ? @"⌧" : UCLocalize("CLEAR");
}

NSString *downgradeString()
{
	return short_ ? @"⇵" : UCLocalize("DOWNGRADE");
}

NSString *normalizedString(NSString *string)
{
	return [string stringByReplacingOccurrencesOfString:@" " withString:@"\n"];
}

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
	NSMutableArray *actions = [NSMutableArray array];
	BOOL installed = ![package uninstalled];
	BOOL upgradable = [package upgradableAndEssential:NO];
	BOOL isQueue = [package mode] != nil;
	bool commercial = [package isCommercial];
	if (installed)
	{
		// remove
		UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:removeString() handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			should = noConfirm;
			[delegate removePackage:package];
		}];
		[actions addObject:deleteAction];
	}
	NSString *format = @"%@\n%@";
	NSString *installTitle = installed ? (upgradable ? upgradeString() : reinstallString()) : (commercial ? buyString() : installString());
	installTitle = normalizedString(installTitle); // In some languages, localized "reinstall" string is too long
	if ((!installed || short_ || IPAD) && !isQueue)
	{
		// install or buy
		UITableViewRowAction *installAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:installTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			should = noConfirm && (!commercial || (commercial && installed));
			if (commercial && !installed) {
				[self didSelectPackage:package];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
					[cy customButtonClicked];
				});	
			}
			else
				[delegate installPackage:package];
		}];
		installAction.backgroundColor = [UIColor systemBlueColor];
		[actions addObject:installAction];
	}
	if (installed && !isQueue)
	{
		// queue (re)install action
		NSString *queueReinstallTitle = [NSString stringWithFormat:format, queueString(), installTitle];
		UITableViewRowAction *queueReinstallAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:queueReinstallTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			should = NO;
			queue = autoDismiss;
			[delegate installPackage:package];
		}];
		queueReinstallAction.backgroundColor = [UIColor orangeColor];
		[actions addObject:queueReinstallAction];
	}
	if (isQueue) {
		// a package is currently in clear state
		UITableViewRowAction *clearAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:clearString() handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			should = NO;
			queue = isQueuing;
			[delegate clearPackage:package];
		}];
		clearAction.backgroundColor = [UIColor grayColor];
		[actions addObject:clearAction];
	} else {
		// queue remove/install
		NSString *queueTitle = [NSString stringWithFormat:format, queueString(), (installed ? removeString() : installTitle)];
		UITableViewRowAction *queueAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:queueTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			should = NO;
			queue = autoDismiss;
			if (installed)
				[delegate removePackage:package];
			else
				[delegate installPackage:package];
		}];
		queueAction.backgroundColor = installed ? [UIColor systemYellowColor] : [UIColor systemGreenColor];
		[actions addObject:queueAction];
	}
	if ([package downgrades].count > 0)
	{
		NSString *downgradeTitle = downgradeString();
		UITableViewRowAction *downgradeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:downgradeTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			should = NO;
			queue = NO;
			[self didSelectPackage:package];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.9*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
				[cy _clickButtonWithName:@"DOWNGRADE"];
			});
		}];
		downgradeAction.backgroundColor = [UIColor purpleColor];
		[actions addObject:downgradeAction];
	}
    return actions;
}

%new
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView setEditing:NO animated:YES];
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