#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import "ChecklCManager.h"
#import "ChecklCPasscodeViewController.h"

#define kChecklCEnabledKey @"com.yourcompany.checklc.enabled"
#define kChecklCBiometricEnabledKey @"com.yourcompany.checklc.biometricEnabled"
#define kChecklCDiagnosticsEnabledKey @"com.yourcompany.checklc.diagnosticsEnabled"
#define kChecklCHapticsEnabledKey @"com.yourcompany.checklc.hapticsEnabled"

@interface ChecklCPrefsController : PSListController
@end

@implementation ChecklCPrefsController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        // Enable ChecklC toggle
        PSSpecifier *enabledToggle = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Enable ChecklC", nil)
                                                                   target:self
                                                                      set:@selector(setEnabled:specifier:)
                                                                      get:@selector(isEnabled:)
                                                                   detail:nil
                                                                     cell:PSSwitchCell
                                                                     edit:nil];
        [enabledToggle setProperty:@"enabled" forKey:@"key"];
        [specs addObject:enabledToggle];
        // Enable Biometrics toggle
        PSSpecifier *biometricToggle = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Enable Biometrics", nil)
                                                                      target:self
                                                                         set:@selector(setBiometricEnabled:specifier:)
                                                                         get:@selector(isBiometricEnabled:)
                                                                      detail:nil
                                                                        cell:PSSwitchCell
                                                                        edit:nil];
        [biometricToggle setProperty:@"biometricEnabled" forKey:@"key"];
        [specs addObject:biometricToggle];
        // Diagnostics toggle
        PSSpecifier *diagnosticsToggle = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Enable Diagnostics", nil)
                                                                        target:self
                                                                           set:@selector(setDiagnosticsEnabled:specifier:)
                                                                           get:@selector(isDiagnosticsEnabled:)
                                                                        detail:nil
                                                                          cell:PSSwitchCell
                                                                          edit:nil];
        [diagnosticsToggle setProperty:@"diagnosticsEnabled" forKey:@"key"];
        [specs addObject:diagnosticsToggle];
        // Haptic feedback toggle
        PSSpecifier *hapticsToggle = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Enable Haptic Feedback", nil)
                                                                    target:self
                                                                       set:@selector(setHapticsEnabled:specifier:)
                                                                       get:@selector(isHapticsEnabled:)
                                                                    detail:nil
                                                                      cell:PSSwitchCell
                                                                      edit:nil];
        [hapticsToggle setProperty:@"hapticsEnabled" forKey:@"key"];
        [specs addObject:hapticsToggle];
        // Reset Passcode button
        PSSpecifier *resetPass = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Reset Passcode", nil)
                                                                target:self set:@selector(resetPasscode) get:nil detail:nil cell:PSButtonCell edit:nil];
        [specs addObject:resetPass];
        // Disable Lock button
        PSSpecifier *disableLock = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Disable Lock", nil)
                                                                  target:self set:@selector(disableLock) get:nil detail:nil cell:PSButtonCell edit:nil];
        [specs addObject:disableLock];
        // Status
        NSString *status = [ChecklCManager sharedInstance].hasPasscode ? NSLocalizedString(@"Enabled", nil) : NSLocalizedString(@"Disabled", nil);
        NSString *biometric = [ChecklCManager sharedInstance].biometricAvailable ? NSLocalizedString(@"Available", nil) : NSLocalizedString(@"Unavailable", nil);
        PSSpecifier *statusCell = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Status", nil)
                                                                 target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [statusCell setProperty:[NSString stringWithFormat:@"%@, %@: %@", status, NSLocalizedString(@"Biometrics", nil), biometric] forKey:@"label"];
        [specs addObject:statusCell];
        _specifiers = specs;
    }
    return _specifiers;
}
- (void)setEnabled:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.yourcompany.checklc"];
    rocketbootstrap_distributedmessagingcenter_apply(defaults);
    [defaults setBool:[value boolValue] forKey:kChecklCEnabledKey];
    [defaults synchronize];
}
- (id)isEnabled:(PSSpecifier *)specifier {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.yourcompany.checklc"];
    rocketbootstrap_distributedmessagingcenter_apply(defaults);
    return @([defaults boolForKey:kChecklCEnabledKey]);
}
- (void)setBiometricEnabled:(id)value specifier:(PSSpecifier *)specifier {
    [ChecklCManager sharedInstance].biometricEnabled = [value boolValue];
}
- (id)isBiometricEnabled:(PSSpecifier *)specifier {
    return @([ChecklCManager sharedInstance].biometricEnabled);
}
- (void)setDiagnosticsEnabled:(id)value specifier:(PSSpecifier *)specifier {
    [ChecklCManager sharedInstance].diagnosticsEnabled = [value boolValue];
}
- (id)isDiagnosticsEnabled:(PSSpecifier *)specifier {
    return @([ChecklCManager sharedInstance].diagnosticsEnabled);
}
- (void)setHapticsEnabled:(id)value specifier:(PSSpecifier *)specifier {
    [ChecklCManager sharedInstance].hapticsEnabled = [value boolValue];
}
- (id)isHapticsEnabled:(PSSpecifier *)specifier {
    return @([ChecklCManager sharedInstance].hapticsEnabled);
}
- (void)resetPasscode {
    ChecklCPasscodeViewController *vc = [[ChecklCPasscodeViewController alloc] init];
    vc.confirmMode = YES;
    vc.onSuccess = ^(NSString *newPass) {
        [[ChecklCManager sharedInstance] setPasscode:newPass];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Success", nil) message:NSLocalizedString(@"Passcode reset.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    };
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:vc animated:YES completion:nil];
}
- (void)disableLock {
    // Require passcode or biometric confirmation
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Disable Lock", nil) message:NSLocalizedString(@"Enter your passcode to disable lock.", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Passcode", nil);
        textField.secureTextEntry = YES;
    }];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSString *input = alert.textFields.firstObject.text;
        if ([[ChecklCManager sharedInstance] disableLockWithConfirmation:input]) {
            UIAlertController *done = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Success", nil) message:NSLocalizedString(@"Lock disabled.", nil) preferredStyle:UIAlertControllerStyleAlert];
            [done addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:done animated:YES completion:nil];
        } else {
            // Try biometric
            if ([[ChecklCManager sharedInstance] disableLockWithConfirmation:nil]) {
                UIAlertController *done = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Success", nil) message:NSLocalizedString(@"Lock disabled.", nil) preferredStyle:UIAlertControllerStyleAlert];
                [done addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
                [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:done animated:YES completion:nil];
            } else {
                UIAlertController *fail = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"Incorrect passcode or biometric failed.", nil) preferredStyle:UIAlertControllerStyleAlert];
                [fail addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
                [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:fail animated:YES completion:nil];
            }
        }
    }];
    [alert addAction:confirm];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}
@end 