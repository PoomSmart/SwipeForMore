#import <UIKit/UIKit.h>

@interface Database : NSObject
+ (instancetype)sharedInstance;
@end

@interface Package : NSObject
- (NSString *)id;
- (NSString *)name;
- (NSString *)latest;
- (NSString *)installed;
- (NSString *)mode;
- (NSArray *)downgrades;
- (BOOL)uninstalled;
- (BOOL)upgradableAndEssential:(BOOL)essential;
- (BOOL)essential;
- (BOOL)broken;
- (BOOL)unfiltered;
- (BOOL)visible;
- (BOOL)half;
- (BOOL)halfConfigured;
- (BOOL)halfInstalled;
- (BOOL)hasMode;
- (bool)isCommercial;
@end

@interface CyteApplication : UIApplication
@end

@interface CyteViewController : UIViewController
@end

@interface CyteListController : CyteViewController
@end

@interface CyteWebViewController : CyteViewController
@end

@interface CYPackageController : NSObject
@end

@interface CydiaWebViewController : CyteWebViewController
@end

@protocol ConfirmationControllerDelegate
- (void)cancelAndClear:(bool)clear;
- (void)confirmWithNavigationController:(UINavigationController *)navigation;
- (void)queue;
@end

@interface ConfirmationController : CydiaWebViewController
@end

@interface PackageListController : CyteListController
- (Package *)packageAtIndexPath:(NSIndexPath *)path;
- (void)didSelectPackage:(Package *)package;
@end

@interface FilteredPackageListController : PackageListController
@end

@interface ProgressController : CydiaWebViewController
@end

@protocol CydiaDelegate
- (void)returnToCydia;
- (void)saveState;
- (void)retainNetworkActivityIndicator;
- (void)releaseNetworkActivityIndicator;
- (void)clearPackage:(Package *)package;
- (void)installPackage:(Package *)package;
- (void)installPackages:(NSArray *)packages;
- (void)removePackage:(Package *)package;
- (void)beginUpdate;
- (BOOL)updating;
- (bool)requestUpdate;
- (void)distUpgrade;
- (void)loadData;
- (void)updateData;
- (void)_saveConfig;
- (void)syncData;
- (void)addSource:(NSDictionary *)source;
- (BOOL)addTrivialSource:(NSString *)href;
- (void)reloadDataWithInvocation:(NSInvocation *)invocation;
@end

@interface Cydia : CyteApplication <ConfirmationControllerDelegate, CydiaDelegate>
@end
