#import <Foundation/Foundation.h>

@interface SwipeActionController : NSObject
+ (instancetype)sharedInstance;
@property (assign) BOOL dismissAfterProgress;
@property (assign) BOOL dismissAsQueue;
@property (assign) BOOL fromSwipeAction;
@property (assign) BOOL fromProgressInvoke;
@property (assign) BOOL autoClickDowngrade;
@property (assign) BOOL autoClickBuy;
 
@property (assign) BOOL shortLabel;
@property (assign) BOOL autoDismissWhenQueue;
@property (assign) BOOL autoPerform;
@property (assign) BOOL suppressCC;

- (NSString *)installString;
- (NSString *)reinstallString;
- (NSString *)upgradeString;
- (NSString *)removeString;
- (NSString *)queueString;
- (NSString *)clearString;
- (NSString *)downgradeString;
- (NSString *)buyString;
- (NSString *)normalizedString:(NSString *)string;
- (NSString *)queueString:(NSString *)action;
@end
