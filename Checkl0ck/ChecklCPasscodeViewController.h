#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <AudioToolbox/AudioToolbox.h>
#import <sys/syslog.h>
#import "ChecklCManager.h"
#import "ChecklCPasscodeViewController.h"

#define PASSCODE_LENGTH 6

/// Appearance struct for theming
typedef struct {
    UIColor *backgroundColor;
    UIColor *dotColor;
    UIColor *dotEmptyColor;
    UIColor *buttonColor;
    UIColor *buttonTextColor;
    UIColor *accentColor;
    UIFont  *titleFont;
    UIFont  *subtitleFont;
    UIFont  *keyFont;
} ChecklCPasscodeAppearance;

NS_ASSUME_NONNULL_BEGIN

@interface ChecklCPasscodeViewController : UIViewController

/// Callbacks
@property (nonatomic, copy, nullable) void (^onSuccess)(NSString *enteredPasscode); // Passcode or nil if biometric
@property (nonatomic, copy, nullable) void (^onFailure)(void);
@property (nonatomic, copy, nullable) void (^onCancel)(void);

/// Enable Face ID/Touch ID button
@property (nonatomic, assign) BOOL biometricAvailable;

/// Configure title/subtitle
- (void)configureWithTitle:(NSString *)title subtitle:(NSString * _Nullable)subtitle;

/// Set custom appearance (call before presenting)
@property (nonatomic, assign) ChecklCPasscodeAppearance appearance;

/// Enable passcode confirmation mode (setup flow)
@property (nonatomic, assign) BOOL confirmMode; // If YES, will ask for passcode twice and call onSuccess only if both match

/// For unit testing: simulate input (no UITextField)
- (void)simulateInput:(NSString *)passcode;

/// Reset input and UI
- (void)resetInput;

/// Show error animation and reset
- (void)showErrorAnimation;

@end

NS_ASSUME_NONNULL_END

static ChecklCPasscodeViewController *g_passcodeVC = nil;

%hook SBLockScreenManager

// Hook the main unlock method (adjust selector if needed for your iOS version)
- (void)attemptUnlockWithPasscode:(NSString *)passcode {
    // If no passcode set, auto-trigger setup on first install
    if (![ChecklCManager sharedInstance] || ![UIApplication sharedApplication]) {
        %orig;
        return;
    }
    if (![self hasChecklCPasscode]) {
        [self presentPasscodeSetup];
        return;
    }
    [self presentPasscodeEntry];
}

// Helper: Check if a passcode exists in Keychain
- (BOOL)hasChecklCPasscode {
    // Try to verify an impossible passcode; returns NO if nothing is set
    return [[ChecklCManager sharedInstance] verifyPasscode:@"000000"] || [[ChecklCManager sharedInstance] verifyPasscode:@"123456"];
}

// Present the passcode entry UI
- (void)presentPasscodeEntry {
    if (g_passcodeVC) return;
    g_passcodeVC = [[ChecklCPasscodeViewController alloc] init];
    [[ChecklCManager sharedInstance] refreshBiometricAvailability];
    g_passcodeVC.biometricAvailable = [ChecklCManager sharedInstance].biometricAvailable;
    [g_passcodeVC configureWithTitle:@"Enter Passcode" subtitle:nil];
    g_passcodeVC.confirmMode = NO;

    // Add blur effect behind the passcode UI
    [self addBlurBehindPasscodeUI];

    __weak typeof(self) weakSelf = self;
    g_passcodeVC.onSuccess = ^(NSString *entered) {
        syslog(LOG_NOTICE, "[ChecklC] Passcode success");
        [weakSelf dismissPasscodeVCAndUnlock:YES];
    };
    g_passcodeVC.onFailure = ^{
        syslog(LOG_NOTICE, "[ChecklC] Passcode failure");
    };
    g_passcodeVC.onCancel = ^{
        syslog(LOG_NOTICE, "[ChecklC] Passcode cancelled");
        [weakSelf dismissPasscodeVCAndUnlock:NO];
    };
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    [root presentViewController:g_passcodeVC animated:YES completion:nil];
}

// Present the passcode setup/confirmation UI
- (void)presentPasscodeSetup {
    if (g_passcodeVC) return;
    g_passcodeVC = [[ChecklCPasscodeViewController alloc] init];
    [[ChecklCManager sharedInstance] refreshBiometricAvailability];
    g_passcodeVC.biometricAvailable = [ChecklCManager sharedInstance].biometricAvailable;
    [g_passcodeVC configureWithTitle:@"Set Passcode" subtitle:@"Enter a new 6-digit passcode."];
    g_passcodeVC.confirmMode = YES;

    // Add blur effect behind the passcode UI
    [self addBlurBehindPasscodeUI];

    __weak typeof(self) weakSelf = self;
    g_passcodeVC.onSuccess = ^(NSString *entered) {
        [[ChecklCManager sharedInstance] setPasscode:entered];
        syslog(LOG_NOTICE, "[ChecklC] Passcode set");
        [weakSelf dismissPasscodeVCAndUnlock:YES];
    };
    g_passcodeVC.onFailure = ^{
        syslog(LOG_NOTICE, "[ChecklC] Passcode setup failed");
    };
    g_passcodeVC.onCancel = ^{
        syslog(LOG_NOTICE, "[ChecklC] Passcode setup cancelled");
        [weakSelf dismissPasscodeVCAndUnlock:NO];
    };
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    [root presentViewController:g_passcodeVC animated:YES completion:nil];
}

// Dismiss the passcode UI and unlock if needed
- (void)dismissPasscodeVCAndUnlock:(BOOL)shouldUnlock {
    if (!g_passcodeVC) return;
    UIView *blur = [self blurViewIfPresent];
    [g_passcodeVC dismissViewControllerAnimated:YES completion:^{
        g_passcodeVC = nil;
        if (blur) [blur removeFromSuperview];
        if (shouldUnlock) {
            // Call the original unlock method
            %orig(@"000000"); // Pass a dummy passcode or the real one if needed
        }
    }];
}

// Add a blur effect behind the passcode UI
- (void)addBlurBehindPasscodeUI {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if ([self blurViewIfPresent]) return;
    UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = window.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.tag = 0xC10C10C; // Unique tag for easy removal
    [window addSubview:blurView];
    [window bringSubviewToFront:blurView];
}

// Find the blur view if present
- (UIView *)blurViewIfPresent {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    return [window viewWithTag:0xC10C10C];
}

// Clean up on respring or reload
%ctor {
    g_passcodeVC = nil;
}

%end