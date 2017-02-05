#import "../PS.h"
#import <Cydia/FilteredPackageListController.h>
#import <Cydia/CYPackageController.h>
#import <Cydia/ConfirmationController.h>
#import <Cydia/ProgressController.h>
#import <Cydia/Cydia-Class.h>
#import "SwipeActionController.h"
#import <notify.h>

BOOL enabled;

#define SAC [SwipeActionController sharedInstance]

BOOL Queuing_;
BOOL suppressCC = NO;

CFStringRef PreferencesNotification = CFSTR("com.PS.SwipeForMore.prefs");
NSString *format = @"%@\n%@";

static void prefs()
{
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.SwipeForMore.plist"];
	id val = prefs[@"enabled"];
	enabled = val ? [val boolValue] : YES;
	val = prefs[@"confirm"];
	SAC.autoPerform = [val boolValue];
	val = prefs[@"autoDismiss"];
	SAC.autoDismissWhenQueue = val ? [val boolValue] : YES;
	val = prefs[@"short"];
	SAC.shortLabel = val ? [val boolValue] : YES;
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	prefs();
}

static _finline void _UpdateExternalStatus(uint64_t newStatus) {
    int notify_token;
    if (notify_register_check("com.saurik.Cydia.status", &notify_token) == NOTIFY_STATUS_OK) {
        notify_set_state(notify_token, newStatus);
        notify_cancel(notify_token);
    }
    notify_post("com.saurik.Cydia.status");
}

#define cyDelegate ((Cydia *)[UIApplication sharedApplication])

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

- (void)reloadDataWithInvocation:(NSInvocation *)invocation
{
	Queuing_ = NO;
	%orig;
}

- (void)confirmWithNavigationController:(UINavigationController *)navigation
{
	Queuing_ = NO;
	%orig;
}

- (void)cancelAndClear:(bool)clear
{
	Queuing_ = !clear;
	%orig;
}

- (bool)perform
{
	[SAC setSuppressCC:[SAC fromSwipeAction] && [SAC dismissAsQueue]];
	bool value = %orig;
	[SAC setSuppressCC:NO];
	[SAC setFromSwipeAction:NO];
	return value;
}

%end

%hook ConfirmationController

- (void)dismissModalViewControllerAnimated:(BOOL)animated
{
	if ([SAC suppressCC])
		return;
	%orig;
}

%end

%hook CydiaTabBarController

- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion
{
	if ([vc isKindOfClass:[UINavigationController class]]) {
		if ([((UINavigationController *)vc).topViewController class] == NSClassFromString(@"ConfirmationController")) {
			ConfirmationController *cc = (ConfirmationController *)(((UINavigationController *)vc).topViewController);
			if (MSHookIvar<NSMutableArray *>(cc, "issues_").count) {
				// Problem detected, won't auto-dismiss here
				%orig;
				return;
			}
			if ([SAC fromSwipeAction]) {
				// some actions needed after package confirmation page presentation triggered by swipe actions
				if ([SAC dismissAsQueue]) {
					if (completion)
						completion();
					[cc performSelector:@selector(_doContinue) withObject:nil afterDelay:0.06];
					[SAC setDismissAsQueue:NO];
					return;
				}
				void (^block)(void) = ^(void) {
					if (completion)
						completion();
					else if ([SAC dismissAfterProgress] && !Queuing_) {
						[cc performSelector:@selector(confirmButtonClicked) withObject:nil afterDelay:0.2];
					}
					[SAC setFromSwipeAction:NO];
				};
				%orig(vc, animated, block);
				return;
			}
		}
	}
	%orig;
}

%end

%hook ProgressController

- (void)invoke:(NSInvocation *)invocation withTitle:(NSString *)title
{
	%orig;
	if ([SAC dismissAfterProgress]) {
		[SAC setDismissAfterProgress:NO];
		uint64_t status = -1;
		int notify_token;
		if (notify_register_check("com.saurik.Cydia.status", &notify_token) == NOTIFY_STATUS_OK) {
			notify_get_state(notify_token, &status);
			notify_cancel(notify_token);
		}
		if (status == 0 && [SAC dismissAfterProgress]) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.22 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
				_UpdateExternalStatus(0);
				[cyDelegate returnToCydia];
				[[[self navigationController] parentOrPresentingViewController] dismissViewControllerAnimated:YES completion:nil];
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
	NSMutableArray *actions = [NSMutableArray array];
	BOOL installed = ![package uninstalled];
	BOOL upgradable = [package upgradableAndEssential:NO];
	BOOL isQueue = [package mode] != nil;
	bool commercial = [package isCommercial];
	if (installed) {
		// uninstall action
		UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:[SAC removeString] handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			[SAC setFromSwipeAction:YES];
			[SAC setDismissAfterProgress:[SAC autoDismissWhenQueue]];
			[delegate removePackage:package];
		}];
		[actions addObject:deleteAction];
	}
	NSString *installTitle = installed ? (upgradable ? [SAC upgradeString] : [SAC reinstallString]) : (commercial ? [SAC buyString] : [SAC installString]);
	installTitle = [SAC normalizedString:installTitle]; // In some languages, localized "reinstall" string is too long
	if ((!installed || IS_IPAD || [SAC shortLabel]) && !isQueue) {
		// Install or reinstall or upgrade action
		UITableViewRowAction *installAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:installTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			[SAC setFromSwipeAction:YES];
			[SAC setDismissAfterProgress:[SAC autoPerform] && (!commercial || (commercial && installed))];
			if (commercial && !installed) {
				[self didSelectPackage:package];
				[cy performSelector:@selector(customButtonClicked) withObject:nil afterDelay:1.3];
			}
			else
				[delegate installPackage:package];
		}];
		installAction.backgroundColor = [UIColor systemBlueColor];
		[actions addObject:installAction];
	}
	if (installed && !isQueue) {
		// Queue reinstall action
		NSString *queueReinstallTitle = [SAC queueString:installTitle];
		UITableViewRowAction *queueReinstallAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:queueReinstallTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
				[SAC setDismissAfterProgress:NO];
				[SAC setDismissAsQueue:[SAC autoDismissWhenQueue]];
				[SAC setFromSwipeAction:YES];
				[delegate installPackage:package];
		}];
		queueReinstallAction.backgroundColor = [UIColor orangeColor];
		[actions addObject:queueReinstallAction];
	}
	if (isQueue) {
		// Clear action
		UITableViewRowAction *clearAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:[SAC clearString] handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			[SAC setDismissAfterProgress:NO];
			[SAC setDismissAsQueue:Queuing_];
			[SAC setFromSwipeAction:YES];
			[delegate clearPackage:package];
		}];
		clearAction.backgroundColor = [UIColor grayColor];
		[actions addObject:clearAction];
	} else {
		// Queue install/remove action
		NSString *queueTitle = [SAC queueString:(installed ? [SAC removeString] : installTitle)];
		UITableViewRowAction *queueAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:queueTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
			[SAC setDismissAfterProgress:NO];
			[SAC setDismissAsQueue:[SAC autoDismissWhenQueue]];
			[SAC setFromSwipeAction:YES];
			if (installed)
				[delegate removePackage:package];
			else
				[delegate installPackage:package];
		}];
		queueAction.backgroundColor = installed ? [UIColor systemYellowColor] : [UIColor systemGreenColor];
		[actions addObject:queueAction];
	}
	if (!isQueue) {
		NSArray *downgrades = [package downgrades];
		if (downgrades.count > 0)	{
			UITableViewRowAction *downgradeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:[SAC downgradeString] handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
				[SAC setDismissAfterProgress:NO];
				[SAC setDismissAsQueue:NO];
				[SAC setFromSwipeAction:YES];
				[self didSelectPackage:package];
				[cy performSelector:@selector(_clickButtonWithName:) withObject:@"DOWNGRADE" afterDelay:0.6];
			}];
			downgradeAction.backgroundColor = [UIColor purpleColor];
			[actions addObject:downgradeAction];
		}
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
