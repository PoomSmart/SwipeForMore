#import "../PS.h"
#import <notify.h>

@interface Package : NSObject
- (NSString *)installed;
- (NSString *)mode;
- (BOOL)essential;
- (BOOL)uninstalled;
- (bool)isCommercial;
- (BOOL)upgradableAndEssential:(BOOL)essential;
@end

@interface Cydia : UIApplication
- (void)distUpgrade;
- (void)queue;
- (void)returnToCydia;
- (void)removePackage:(Package *)package;
- (void)installPackage:(Package *)package;
- (void)clearPackage:(Package *)package;
- (void)showActionSheet:(UIActionSheet *)sheet fromItem:(UIBarButtonItem *)item;
@end

@interface Source : NSObject
@end

@interface Database : NSObject
@end

@interface ConfirmationController : UIViewController
- (id)initWithDatabase:(Database *)database;
- (void)complete;
- (void)_doContinue;
@end

@interface CyteViewController : UIViewController
@end

@interface CyteTabBarController : UITabBarController
@end

@interface CyteWebViewController : CyteViewController
- (void)customButtonClicked;
@end

@interface CydiaWebViewController : CyteWebViewController
@end

@interface CYPackageController : CydiaWebViewController
- (void)_customButtonClicked;
@end

@interface CydiaTabBarController : CyteTabBarController <UITabBarControllerDelegate>
- (BOOL)updating;
@end

@interface PackageListController : CyteViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>
- (Package *)packageAtIndexPath:(NSIndexPath *)path;
@end

@interface FilteredPackageListController : PackageListController
@end

@interface ProgressController : UIViewController {
	unsigned cancel_;
}
@end

@interface SearchController : FilteredPackageListController <UISearchBarDelegate> {
    BOOL searchloaded_;
    bool summary_;
}
- (id)initWithDatabase:(Database *)database query:(NSString *)query;
@end

@interface InstalledController : FilteredPackageListController
- (id)initWithDatabase:(Database *)database;
- (void)queueButtonClicked;
@end

@interface SectionController : FilteredPackageListController
- (id)initWithDatabase:(Database *)database source:(Source *)source section:(NSString *)section;
@end

@interface ChangesController : FilteredPackageListController {
    unsigned upgrades_;
}
- (id) initWithDatabase:(Database *)database;
@end