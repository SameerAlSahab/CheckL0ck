#import "Checkl0ckManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <sys/syslog.h>

#define kCheckl0ckPrefsDomain @"com.yourcompany.checkl0ck"
#define kPasscodeKey @"isPasscodeEnabled"
#define kBiometricsKey @"biometricsEnabled"

@interface Checkl0ckManager ()
@property (nonatomic, assign, readwrite) LABiometryType biometryType;
@end

@implementation Checkl0ckManager

+ (instancetype)sharedInstance {
    static Checkl0ckManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        [shared refreshState];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self refreshState];
    }
    return self;
}

- (void)setIsPasscodeEnabled:(BOOL)isPasscodeEnabled {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kCheckl0ckPrefsDomain];
    if (!defaults) defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:isPasscodeEnabled forKey:kPasscodeKey];
    [defaults synchronize];
    _isPasscodeEnabled = isPasscodeEnabled;
    syslog(LOG_NOTICE, "[Checkl0ck] Passcode enabled set to %d", isPasscodeEnabled);
}

- (void)setBiometricsEnabled:(BOOL)biometricsEnabled {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kCheckl0ckPrefsDomain];
    if (!defaults) defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:biometricsEnabled forKey:kBiometricsKey];
    [defaults synchronize];
    _biometricsEnabled = biometricsEnabled;
    syslog(LOG_NOTICE, "[Checkl0ck] Biometrics enabled set to %d", biometricsEnabled);
}

- (void)refreshState {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kCheckl0ckPrefsDomain];
    if (!defaults) defaults = [NSUserDefaults standardUserDefaults];
    _isPasscodeEnabled = [defaults objectForKey:kPasscodeKey] ? [defaults boolForKey:kPasscodeKey] : YES;
    _biometricsEnabled = [defaults objectForKey:kBiometricsKey] ? [defaults boolForKey:kBiometricsKey] : YES;
    self.biometryType = [self detectBiometryType];
    syslog(LOG_NOTICE, "[Checkl0ck] State refreshed: passcode=%d, biometrics=%d, biometryType=%ld", _isPasscodeEnabled, _biometricsEnabled, (long)self.biometryType);
}

- (LABiometryType)detectBiometryType {
    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;
    [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    return context.biometryType;
}

+ (BOOL)isJailbroken {
    NSArray *jailbreakPaths = @[ @"/bin/bash", @"/usr/sbin/sshd", @"/etc/apt", @"/Library/MobileSubstrate/MobileSubstrate.dylib" ];
    for (NSString *path in jailbreakPaths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return YES;
        }
    }
    return NO;
}
@end 