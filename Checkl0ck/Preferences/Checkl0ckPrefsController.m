#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "Checkl0ckManager.h"

@interface Checkl0ckPrefsController : PSListController
@end

@implementation Checkl0ckPrefsController
- (NSArray *)specifiers {
    if (!_specifiers) {
        PSSpecifier *passcodeToggle = [PSSpecifier preferenceSpecifierNamed:@"Enable Passcode"
                                                             target:self
                                                                set:@selector(setPasscodeEnabled:specifier:)
                                                                get:@selector(isPasscodeEnabled:)
                                                             detail:Nil
                                                               cell:PSSwitchCell
                                                               edit:Nil];
        [passcodeToggle setProperty:@"Checkl0ckPasscodeEnabled" forKey:@"key"];

        PSSpecifier *biometricToggle = [PSSpecifier preferenceSpecifierNamed:@"Enable Biometrics"
                                                             target:self
                                                                set:@selector(setBiometricsEnabled:specifier:)
                                                                get:@selector(isBiometricsEnabled:)
                                                             detail:Nil
                                                               cell:PSSwitchCell
                                                               edit:Nil];
        [biometricToggle setProperty:@"Checkl0ckBiometricsEnabled" forKey:@"key"];

        PSSpecifier *jailbreak = [PSSpecifier preferenceSpecifierNamed:@"Jailbreak State"
                                                                target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [jailbreak setProperty:[Checkl0ckManager isJailbroken] ? @"Jailbroken" : @"Not Jailbroken" forKey:@"label"];

        NSString *biometryString = @"None";
        LABiometryType type = [Checkl0ckManager sharedInstance].biometryType;
        if (type == LABiometryTypeFaceID) biometryString = @"Face ID";
        else if (type == LABiometryTypeTouchID) biometryString = @"Touch ID";
        PSSpecifier *biometryType = [PSSpecifier preferenceSpecifierNamed:@"Biometry Type"
                                                                   target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [biometryType setProperty:biometryString forKey:@"label"];

        PSSpecifier *status = [PSSpecifier preferenceSpecifierNamed:@"Tweak Status"
                                                             target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [status setProperty:[Checkl0ckManager sharedInstance].isPasscodeEnabled ? @"Active" : @"Inactive" forKey:@"label"];

        // Diagnostics button
        PSSpecifier *diagnostics = [PSSpecifier preferenceSpecifierNamed:@"Diagnostics"
                                                                  target:self
                                                                     set:nil
                                                                     get:nil
                                                                  detail:nil
                                                                    cell:PSButtonCell
                                                                    edit:nil];
        [diagnostics setProperty:@"showDiagnostics" forKey:@"action"];

        // Footer for biometry type
        PSSpecifier *footer = [PSSpecifier emptyGroupSpecifier];
        [footer setProperty:[NSString stringWithFormat:@"Biometry Type: %@", biometryString] forKey:@"footerText"];

        _specifiers = @[passcodeToggle, biometricToggle, jailbreak, biometryType, status, diagnostics, footer];
    }
    return _specifiers;
}

- (void)setPasscodeEnabled:(id)value specifier:(PSSpecifier *)specifier {
    BOOL oldValue = [Checkl0ckManager sharedInstance].isPasscodeEnabled;
    BOOL newValue = [value boolValue];
    if (oldValue != newValue) {
        [self triggerMediumHaptic];
        [Checkl0ckManager sharedInstance].isPasscodeEnabled = newValue;
    }
}
- (id)isPasscodeEnabled:(PSSpecifier *)specifier {
    return @([Checkl0ckManager sharedInstance].isPasscodeEnabled);
}
- (void)setBiometricsEnabled:(id)value specifier:(PSSpecifier *)specifier {
    BOOL oldValue = [Checkl0ckManager sharedInstance].biometricsEnabled;
    BOOL newValue = [value boolValue];
    if (oldValue != newValue) {
        [self triggerMediumHaptic];
        [Checkl0ckManager sharedInstance].biometricsEnabled = newValue;
    }
}
- (id)isBiometricsEnabled:(PSSpecifier *)specifier {
    return @([Checkl0ckManager sharedInstance].biometricsEnabled);
}

- (void)triggerMediumHaptic {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator prepare];
        [generator impactOccurred];
    }
}

- (void)showDiagnostics {
    // Run syslog command and filter for [Checkl0ck]
    NSString *log = [self fetchCheckl0ckSyslog];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Checkl0ck Diagnostics"
                                                                   message:log.length ? log : @"No recent log entries."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    // Find topmost view controller
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:alert animated:YES completion:nil];
}

- (NSString *)fetchCheckl0ckSyslog {
    // Try to read last 100 lines of syslog and filter for [Checkl0ck]
    NSMutableString *result = [NSMutableString string];
    FILE *fp = popen("log show --predicate 'eventMessage contains \"[Checkl0ck]\"' --style syslog --last 5m | tail -n 100", "r");
    if (fp) {
        char buffer[1024];
        while (fgets(buffer, sizeof(buffer), fp)) {
            [result appendString:[NSString stringWithUTF8String:buffer]];
        }
        pclose(fp);
    }
    return result;
}
@end 