#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>

@interface Checkl0ckManager : NSObject
+ (instancetype)sharedInstance;
@property (nonatomic, assign) BOOL isPasscodeEnabled;
@property (nonatomic, assign) BOOL biometricsEnabled;
@property (nonatomic, readonly) LABiometryType biometryType;
+ (BOOL)isJailbroken;
- (void)refreshState;
@end 