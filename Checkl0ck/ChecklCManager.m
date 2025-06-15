#import "ChecklCManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>

#define kChecklCPasscodeService @"com.checklc.passcode"
#define kChecklCPasscodeAccount @"user"
#define kChecklCLockoutKey @"com.checklc.lockout"
#define kChecklCFailedAttemptsKey @"com.checklc.failedAttempts"
#define kChecklCBiometricEnabledKey @"com.checklc.biometricEnabled"
#define MAX_ATTEMPTS 5
#define BASE_LOCKOUT 60

@interface ChecklCManager ()
@property (nonatomic, assign) NSInteger failedAttempts;
@property (nonatomic, strong) NSDate *lockoutStart;
@property (nonatomic, assign) NSTimeInterval lockoutDuration;
@property (nonatomic, assign) BOOL biometricAvailable;
@end

@implementation ChecklCManager

+ (instancetype)sharedInstance {
    static ChecklCManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        [shared refreshBiometricAvailability];
        [shared loadLockoutState];
    });
    return shared;
}

- (BOOL)setPasscode:(NSString *)passcode {
    [self clearPasscode];
    NSData *data = [passcode dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kChecklCPasscodeService,
        (__bridge id)kSecAttrAccount: kChecklCPasscodeAccount,
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    };
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    [self resetLockout];
    return (status == errSecSuccess);
}

- (BOOL)verifyPasscode:(NSString *)input {
    if ([self isLockedOut]) return NO;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kChecklCPasscodeService,
        (__bridge id)kSecAttrAccount: kChecklCPasscodeAccount,
        (__bridge id)kSecReturnData: @YES
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) return NO;
    NSData *data = (__bridge_transfer NSData *)result;
    NSString *stored = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    BOOL match = [stored isEqualToString:input];
    if (!match) [self registerFailedAttempt];
    else [self resetLockout];
    return match;
}

- (void)clearPasscode {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kChecklCPasscodeService,
        (__bridge id)kSecAttrAccount: kChecklCPasscodeAccount
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
    [self resetLockout];
}

- (BOOL)hasPasscode {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kChecklCPasscodeService,
        (__bridge id)kSecAttrAccount: kChecklCPasscodeAccount,
        (__bridge id)kSecReturnData: @NO
    };
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    return (status == errSecSuccess);
}

- (void)refreshBiometricAvailability {
    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;
    self.biometricAvailable = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
}

- (BOOL)biometricEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kChecklCBiometricEnabledKey];
}
- (void)setBiometricEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kChecklCBiometricEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// Lockout logic
- (void)registerFailedAttempt {
    self.failedAttempts++;
    [[NSUserDefaults standardUserDefaults] setInteger:self.failedAttempts forKey:kChecklCFailedAttemptsKey];
    if (self.failedAttempts >= MAX_ATTEMPTS) {
        self.lockoutStart = [NSDate date];
        self.lockoutDuration = BASE_LOCKOUT * pow(2, self.failedAttempts - MAX_ATTEMPTS);
        [[NSUserDefaults standardUserDefaults] setObject:self.lockoutStart forKey:kChecklCLockoutKey];
        [[NSUserDefaults standardUserDefaults] setDouble:self.lockoutDuration forKey:@"com.checklc.lockoutDuration"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)resetLockout {
    self.failedAttempts = 0;
    self.lockoutStart = nil;
    self.lockoutDuration = 0;
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kChecklCFailedAttemptsKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kChecklCLockoutKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"com.checklc.lockoutDuration"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)loadLockoutState {
    self.failedAttempts = [[NSUserDefaults standardUserDefaults] integerForKey:kChecklCFailedAttemptsKey];
    self.lockoutStart = [[NSUserDefaults standardUserDefaults] objectForKey:kChecklCLockoutKey];
    self.lockoutDuration = [[NSUserDefaults standardUserDefaults] doubleForKey:@"com.checklc.lockoutDuration"];
}
- (BOOL)isLockedOut {
    if (self.failedAttempts < MAX_ATTEMPTS) return NO;
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.lockoutStart];
    return elapsed < self.lockoutDuration;
}
- (NSTimeInterval)remainingLockoutTime {
    if (![self isLockedOut]) return 0;
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.lockoutStart];
    return MAX(0, self.lockoutDuration - elapsed);
}
@end 