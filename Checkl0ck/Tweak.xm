#import <LocalAuthentication/LocalAuthentication.h>
#import "Checkl0ckManager.h"
#import <sys/syslog.h>
#import <UIKit/UIKit.h>
#import "ChecklCManager.h"
#import "ChecklCPasscodeViewController.h"

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

// Remove the blur view if present
static void RemoveChecklCBlur(void) {
    if (g_blurView) {
        [g_blurView removeFromSuperview];
        g_blurView = nil;
    }
}

// Dismiss the passcode UI and clean up
static void DismissChecklCPasscodeVC(BOOL animated, void (^completion)(void)) {
    if (!g_passcodeVC) { if (completion) completion(); return; }
    [g_passcodeVC dismissViewControllerAnimated:animated completion:^{
        g_passcodeVC = nil;
        RemoveChecklCBlur();
        if (completion) completion();
    }];
}

%hook SBLockScreenManager
- (BOOL)isPasscodeSet {
    [[Checkl0ckManager sharedInstance] refreshState];
    if (![Checkl0ckManager isJailbroken]) {
        syslog(LOG_NOTICE, "[Checkl0ck] Not jailbroken, using original passcode state");
        return %orig;
    }
    BOOL enabled = [Checkl0ckManager sharedInstance].isPasscodeEnabled;
    syslog(LOG_NOTICE, "[Checkl0ck] isPasscodeSet called, returning %d", enabled);
    return enabled;
}

- (void)attemptUnlockWithPasscode:(NSString *)passcode {
    if (g_unlockInProgress) { %orig(passcode); return; }
    if (![ChecklCManager sharedInstance] || ![UIApplication sharedApplication]) {
        %orig(passcode);
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
            [weakSelf _checklC_performUnlockWithPasscode:entered];
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
        // Optionally disable keypad in ChecklCPasscodeViewController
    } else {
        // Show a simple alert if not in passcode UI
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
            [weakSelf _checklC_performUnlockWithPasscode:entered];
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

- (void)_checklC_performUnlockWithPasscode:(NSString *)passcode {
    %orig(passcode ?: @"000000");
}

// TODO: Block Spotlight, Camera, Control Center when locked by hooking relevant SB classes/methods.
// TODO: Clean up on memory warning, respring, or reload.

%end

%hook LAContext
- (BOOL)canEvaluatePolicy:(LAPolicy)policy error:(NSError **)error {
    [[Checkl0ckManager sharedInstance] refreshState];
    if (![Checkl0ckManager isJailbroken]) {
        syslog(LOG_NOTICE, "[Checkl0ck] Not jailbroken, using original biometric state");
        return %orig;
    }
    BOOL enabled = [Checkl0ckManager sharedInstance].biometricsEnabled;
    syslog(LOG_NOTICE, "[Checkl0ck] canEvaluatePolicy called, returning %d", enabled);
    return enabled;
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

%ctor {
    g_passcodeVC = nil;
    g_blurView = nil;
    g_unlockInProgress = NO;
} 