#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sys/syslog.h>
#import "ChecklCManager.h"
#import "ChecklCPasscodeViewController.h"

@interface ChecklCManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)setPasscode:(NSString *)passcode;
- (BOOL)verifyPasscode:(NSString *)input;
- (void)clearPasscode;
- (BOOL)hasPasscode;
@property (nonatomic, readonly) BOOL biometricAvailable;
@property (nonatomic, assign) BOOL biometricEnabled;
- (void)refreshBiometricAvailability;
// Lockout
@property (nonatomic, readonly) NSInteger failedAttempts;
@property (nonatomic, readonly) BOOL isLockedOut;
@property (nonatomic, readonly) NSTimeInterval remainingLockoutTime;
- (void)registerFailedAttempt;
- (void)resetLockout;
@end

static ChecklCPasscodeViewController *g_passcodeVC = nil;
static UIVisualEffectView *g_blurView = nil;
static BOOL g_unlockInProgress = NO;

// Add a dark blur effect behind the passcode UI
static void AddChecklCBlur(void) {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window || g_blurView) return;
    UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    g_blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    g_blurView.frame = window.bounds;
    g_blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    g_blurView.userInteractionEnabled = NO;
    [window addSubview:g_blurView];
    [window bringSubviewToFront:g_blurView];
}

static void RemoveChecklCBlur(void) {
    if (g_blurView) {
        [g_blurView removeFromSuperview];
        g_blurView = nil;
    }
}

static void DismissChecklCPasscodeVC(BOOL animated, void (^completion)(void)) {
    if (!g_passcodeVC) { if (completion) completion(); return; }
    [g_passcodeVC dismissViewControllerAnimated:animated completion:^{
        g_passcodeVC = nil;
        RemoveChecklCBlur();
        if (completion) completion();
    }];
}

// %c for rootless compatibility
%group ChecklC

%hookf(void, SBLockScreenManager_attemptUnlockWithPasscode, id self, SEL _cmd, NSString *passcode) {
    if (g_unlockInProgress) { %orig(self, _cmd, passcode); return; }
    if (![ChecklCManager sharedInstance] || ![UIApplication sharedApplication]) {
        %orig(self, _cmd, passcode);
        return;
    }
    if ([[ChecklCManager sharedInstance] isLockedOut]) {
        [self presentLockoutUI];
        return;
    }
    if (![[ChecklCManager sharedInstance] hasPasscode]) {
        [self presentChecklCPasscodeSetup];
        return;
    }
    [self presentChecklCPasscodeEntry];
}

- (void)presentChecklCPasscodeEntry {
    if (g_passcodeVC) return;
    g_passcodeVC = [[ChecklCPasscodeViewController alloc] init];
    [[ChecklCManager sharedInstance] refreshBiometricAvailability];
    g_passcodeVC.biometricAvailable = [ChecklCManager sharedInstance].biometricAvailable && [ChecklCManager sharedInstance].biometricEnabled;
    [g_passcodeVC configureWithTitle:@"Enter Passcode" subtitle:nil];
    g_passcodeVC.confirmMode = NO;
    AddChecklCBlur();
    __weak typeof(self) weakSelf = self;
    g_passcodeVC.onSuccess = ^(NSString *entered) {
        syslog(LOG_NOTICE, "[ChecklC] Passcode success");
        [[ChecklCManager sharedInstance] resetLockout];
        g_unlockInProgress = YES;
        DismissChecklCPasscodeVC(YES, ^{
            %orig(weakSelf, @selector(attemptUnlockWithPasscode:), entered ?: @"000000");
            g_unlockInProgress = NO;
        });
    };
    g_passcodeVC.onFailure = ^{
        syslog(LOG_NOTICE, "[ChecklC] Passcode failure");
        [[ChecklCManager sharedInstance] registerFailedAttempt];
        if ([[ChecklCManager sharedInstance] isLockedOut]) {
            [weakSelf presentLockoutUI];
        }
    };
    g_passcodeVC.onCancel = ^{
        syslog(LOG_NOTICE, "[ChecklC] Passcode cancelled");
        DismissChecklCPasscodeVC(YES, nil);
    };
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    [root presentViewController:g_passcodeVC animated:YES completion:nil];
}

- (void)presentLockoutUI {
    if (g_passcodeVC) {
        [g_passcodeVC showError:[NSString stringWithFormat:@"Try again in %.0f seconds", [[ChecklCManager sharedInstance] remainingLockoutTime]]];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Locked Out"
                                                                       message:[NSString stringWithFormat:@"Try again in %.0f seconds", [[ChecklCManager sharedInstance] remainingLockoutTime]]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
        [root presentViewController:alert animated:YES completion:nil];
    }
}

- (void)presentChecklCPasscodeSetup {
    if (g_passcodeVC) return;
    g_passcodeVC = [[ChecklCPasscodeViewController alloc] init];
    [[ChecklCManager sharedInstance] refreshBiometricAvailability];
    g_passcodeVC.biometricAvailable = [ChecklCManager sharedInstance].biometricAvailable && [ChecklCManager sharedInstance].biometricEnabled;
    [g_passcodeVC configureWithTitle:@"Set Passcode" subtitle:@"Enter a new 6-digit passcode."];
    g_passcodeVC.confirmMode = YES;
    AddChecklCBlur();
    __weak typeof(self) weakSelf = self;
    g_passcodeVC.onSuccess = ^(NSString *entered) {
        [[ChecklCManager sharedInstance] setPasscode:entered];
        syslog(LOG_NOTICE, "[ChecklC] Passcode set");
        [[ChecklCManager sharedInstance] resetLockout];
        g_unlockInProgress = YES;
        DismissChecklCPasscodeVC(YES, ^{
            %orig(weakSelf, @selector(attemptUnlockWithPasscode:), entered ?: @"000000");
            g_unlockInProgress = NO;
        });
    };
    g_passcodeVC.onFailure = ^{
        syslog(LOG_NOTICE, "[ChecklC] Passcode setup failed");
    };
    g_passcodeVC.onCancel = ^{
        syslog(LOG_NOTICE, "[ChecklC] Passcode setup cancelled");
        DismissChecklCPasscodeVC(YES, nil);
    };
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    [root presentViewController:g_passcodeVC animated:YES completion:nil];
}

%end

// Block Control Center when locked
%hook SBControlCenterController
- (BOOL)_canShowWhileLocked {
    if ([ChecklCManager sharedInstance].isLockedOut || [[ChecklCManager sharedInstance] hasPasscode]) {
        return NO;
    }
    return %orig;
}
%end

// Block Spotlight when locked
%hook SBSearchGesture
- (BOOL)isAvailableWhileLocked {
    if ([ChecklCManager sharedInstance].isLockedOut || [[ChecklCManager sharedInstance] hasPasscode]) {
        return NO;
    }
    return %orig;
}
%end

// Block Camera from lock screen when locked
%hook SBCameraHardwareButton
- (BOOL)canActivateCameraWhileLocked {
    if ([ChecklCManager sharedInstance].isLockedOut || [[ChecklCManager sharedInstance] hasPasscode]) {
        return NO;
    }
    return %orig;
}
%end

// Clean up on memory warning
%hook SpringBoard
- (void)didReceiveMemoryWarning {
    g_passcodeVC = nil;
    g_blurView = nil;
    g_unlockInProgress = NO;
    %orig;
}
%end

%end

%ctor {
    g_passcodeVC = nil;
    g_blurView = nil;
    g_unlockInProgress = NO;
    %init(ChecklC);
} 