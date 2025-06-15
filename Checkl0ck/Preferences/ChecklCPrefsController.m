#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "ChecklCManager.h"
#import "ChecklCPasscodeViewController.h"

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
        // Change Passcode button
        PSSpecifier *changePass = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Change Passcode", nil)
                                                                target:self set:@selector(changePasscode) get:nil detail:nil cell:PSButtonCell edit:nil];
        [specs addObject:changePass];
        // Remove Passcode button
        PSSpecifier *removePass = [PSSpecifier preferenceSpecifierNamed:NSLocalizedString(@"Remove Passcode", nil)
                                                                target:self set:@selector(removePasscode) get:nil detail:nil cell:PSButtonCell edit:nil];
        [specs addObject:removePass];
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
    [[NSUserDefaults standardUserDefaults] setBool:[value boolValue] forKey:@"enabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (id)isEnabled:(PSSpecifier *)specifier {
    return @([[NSUserDefaults standardUserDefaults] boolForKey:@"enabled"]);
}
- (void)setBiometricEnabled:(id)value specifier:(PSSpecifier *)specifier {
    [ChecklCManager sharedInstance].biometricEnabled = [value boolValue];
}
- (id)isBiometricEnabled:(PSSpecifier *)specifier {
    return @([ChecklCManager sharedInstance].biometricEnabled);
}
- (void)changePasscode {
    ChecklCPasscodeViewController *vc = [[ChecklCPasscodeViewController alloc] init];
    vc.confirmMode = YES;
    vc.onSuccess = ^(NSString *newPass) {
        [[ChecklCManager sharedInstance] setPasscode:newPass];
        // Show success alert
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Success", nil) message:NSLocalizedString(@"Passcode changed.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    };
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:vc animated:YES completion:nil];
}
- (void)removePasscode {
    ChecklCPasscodeViewController *vc = [[ChecklCPasscodeViewController alloc] init];
    vc.confirmMode = NO;
    vc.onSuccess = ^(NSString *entered) {
        if ([[ChecklCManager sharedInstance] verifyPasscode:entered]) {
            [[ChecklCManager sharedInstance] clearPasscode];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Success", nil) message:NSLocalizedString(@"Passcode removed.", nil) preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"Incorrect passcode.", nil) preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        }
    };
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:vc animated:YES completion:nil];
}
@end 