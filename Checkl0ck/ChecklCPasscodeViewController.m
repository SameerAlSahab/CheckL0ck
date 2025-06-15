#import "ChecklCPasscodeViewController.h"
#import "ChecklCManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <AudioToolbox/AudioToolbox.h>

#define PASSCODE_LENGTH 6

@interface ChecklCPasscodeViewController ()
@property (nonatomic, strong) NSMutableString *input;
@property (nonatomic, strong) UIStackView *dotsStack;
@property (nonatomic, strong) NSArray<UIView *> *dotViews;
@property (nonatomic, strong) UIStackView *keypadStack;
@property (nonatomic, strong) UIButton *faceIDButton;
@property (nonatomic, strong) UILabel *lockoutLabel;
@property (nonatomic, strong) NSTimer *lockoutTimer;
@end

@implementation ChecklCPasscodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.input = [NSMutableString string];
    [self setupDots];
    [self setupKeypad];
    [self setupFaceIDButtonIfNeeded];
    [self setupLockoutLabel];
    [self checkLockoutState];
}

#pragma mark - UI Setup

- (void)setupDots {
    NSMutableArray *dots = [NSMutableArray array];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 16;
    for (int i = 0; i < PASSCODE_LENGTH; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.backgroundColor = [UIColor labelColor];
        dot.layer.cornerRadius = 10;
        dot.layer.masksToBounds = YES;
        dot.alpha = 0.2;
        [dot.widthAnchor constraintEqualToConstant:20].active = YES;
        [dot.heightAnchor constraintEqualToConstant:20].active = YES;
        [stack addArrangedSubview:dot];
        [dots addObject:dot];
    }
    [self.view addSubview:stack];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:80],
    ]];
    self.dotsStack = stack;
    self.dotViews = dots;
}

- (void)setupKeypad {
    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.distribution = UIStackViewDistributionEqualSpacing;
    mainStack.alignment = UIStackViewAlignmentCenter;
    mainStack.spacing = 12;
    for (int row = 0; row < 4; row++) {
        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.distribution = UIStackViewDistributionEqualSpacing;
        rowStack.alignment = UIStackViewAlignmentCenter;
        rowStack.spacing = 12;
        for (int col = 0; col < 3; col++) {
            int number = row * 3 + col + 1;
            UIButton *button = nil;
            if (row == 3) {
                if (col == 0) {
                    // Cancel
                    button = [self systemButtonWithTitle:NSLocalizedString(@"Cancel", nil) action:@selector(cancelTapped)];
                } else if (col == 1) {
                    number = 0;
                    button = [self numberButton:number];
                } else if (col == 2) {
                    // Delete
                    button = [self systemButtonWithTitle:NSLocalizedString(@"Delete", nil) action:@selector(deleteTapped)];
                }
            } else {
                button = [self numberButton:number];
            }
            [rowStack addArrangedSubview:button];
        }
        [mainStack addArrangedSubview:rowStack];
    }
    [self.view addSubview:mainStack];
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [mainStack.topAnchor constraintEqualToAnchor:self.dotsStack.bottomAnchor constant:40],
    ]];
    self.keypadStack = mainStack;
}

- (UIButton *)numberButton:(NSInteger)number {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:[NSString stringWithFormat:@"%ld", (long)number] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightMedium];
    button.backgroundColor = [UIColor secondarySystemBackgroundColor];
    button.layer.cornerRadius = 32;
    button.layer.masksToBounds = YES;
    button.tintColor = [UIColor labelColor];
    [button.widthAnchor constraintEqualToConstant:64].active = YES;
    [button.heightAnchor constraintEqualToConstant:64].active = YES;
    button.tag = number;
    [button addTarget:self action:@selector(numberTapped:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)systemButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightRegular];
    button.backgroundColor = [UIColor clearColor];
    button.tintColor = [UIColor systemBlueColor];
    [button.widthAnchor constraintEqualToConstant:64].active = YES;
    [button.heightAnchor constraintEqualToConstant:64].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setupFaceIDButtonIfNeeded {
    if (!self.faceIDAvailable) return;
    UIButton *faceID = [UIButton buttonWithType:UIButtonTypeSystem];
    [faceID setImage:[UIImage systemImageNamed:@"faceid"] forState:UIControlStateNormal];
    faceID.tintColor = [UIColor systemGrayColor];
    faceID.contentMode = UIViewContentModeScaleAspectFit;
    [faceID.widthAnchor constraintEqualToConstant:40].active = YES;
    [faceID.heightAnchor constraintEqualToConstant:40].active = YES;
    [faceID addTarget:self action:@selector(faceIDTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:faceID];
    faceID.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [faceID.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [faceID.topAnchor constraintEqualToAnchor:self.keypadStack.bottomAnchor constant:24],
    ]];
    self.faceIDButton = faceID;
}

- (void)setupLockoutLabel {
    UILabel *label = [[UILabel alloc] init];
    label.textColor = [UIColor systemRedColor];
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.alpha = 0;
    [self.view addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.topAnchor constraintEqualToAnchor:self.dotsStack.bottomAnchor constant:12],
        [label.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor multiplier:0.8]
    ]];
    self.lockoutLabel = label;
}

#pragma mark - Keypad Actions

- (void)numberTapped:(UIButton *)sender {
    if (self.input.length >= PASSCODE_LENGTH) return;
    [self.input appendFormat:@"%ld", (long)sender.tag];
    [self updateDots];
    [self triggerKeypressHaptic];
    if (self.input.length == PASSCODE_LENGTH) {
        [self verifyPasscode];
    }
}

- (void)deleteTapped {
    if (self.input.length > 0) {
        [self.input deleteCharactersInRange:NSMakeRange(self.input.length - 1, 1)];
        [self updateDots];
        [self triggerKeypressHaptic];
    }
}

- (void)cancelTapped {
    [self triggerKeypressHaptic];
    if (self.onCancel) self.onCancel();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)faceIDTapped {
    [self triggerKeypressHaptic];
    [self attemptBiometricUnlock];
}

#pragma mark - Passcode Logic

- (void)verifyPasscode {
    // Call success/failure callbacks; actual verification logic is external
    if (self.onSuccess) {
        self.onSuccess(self.input.copy);
    }
}

- (void)resetInput {
    [self.input setString:@""];
    [self updateDots];
}

- (void)showErrorAnimation {
    [self triggerErrorHaptic];
    // Spring shake animation
    [UIView animateWithDuration:0.15 delay:0 usingSpringWithDamping:0.2 initialSpringVelocity:6 options:0 animations:^{
        self.dotsStack.transform = CGAffineTransformMakeTranslation(20, 0);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 delay:0 usingSpringWithDamping:0.2 initialSpringVelocity:6 options:0 animations:^{
            self.dotsStack.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
    [self resetInput];
    if (self.onFailure) self.onFailure();
}

- (void)updateDots {
    for (int i = 0; i < self.dotViews.count; i++) {
        UIView *dot = self.dotViews[i];
        dot.alpha = (i < self.input.length) ? 1.0 : 0.2;
    }
}

#pragma mark - Haptics

- (void)triggerKeypressHaptic {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
    } else {
        AudioServicesPlaySystemSound(1104);
    }
}

- (void)triggerErrorHaptic {
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
        [gen notificationOccurred:UINotificationFeedbackTypeError];
    } else {
        AudioServicesPlaySystemSound(1107);
    }
}

#pragma mark - Biometrics

- (void)attemptBiometricUnlock {
    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                localizedReason:NSLocalizedString(@"Unlock with Face ID/Touch ID", nil)
                          reply:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    if (self.onSuccess) self.onSuccess(nil);
                } else {
                    [self showErrorAnimation];
                }
            });
        }];
    } else {
        [self showErrorAnimation];
    }
}

- (void)checkLockoutState {
    if ([ChecklCManager sharedInstance].isLockedOut) {
        [self showLockout];
    } else {
        [self hideLockout];
    }
}

- (void)showLockout {
    [self updateLockoutLabel];
    self.lockoutLabel.alpha = 1;
    [self setKeypadEnabled:NO];
    [self startLockoutTimer];
}

- (void)hideLockout {
    self.lockoutLabel.alpha = 0;
    [self setKeypadEnabled:YES];
    [self stopLockoutTimer];
}

- (void)updateLockoutLabel {
    NSInteger seconds = (NSInteger)[ChecklCManager sharedInstance].remainingLockoutTime;
    self.lockoutLabel.text = [NSString stringWithFormat:@"Try again in %ld seconds", (long)seconds];
}

- (void)startLockoutTimer {
    [self stopLockoutTimer];
    self.lockoutTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(lockoutTimerFired) userInfo:nil repeats:YES];
}

- (void)stopLockoutTimer {
    [self.lockoutTimer invalidate];
    self.lockoutTimer = nil;
}

- (void)lockoutTimerFired {
    if (![ChecklCManager sharedInstance].isLockedOut) {
        [self hideLockout];
    } else {
        [self updateLockoutLabel];
    }
}

- (void)setKeypadEnabled:(BOOL)enabled {
    self.keypadStack.userInteractionEnabled = enabled;
    self.keypadStack.alpha = enabled ? 1.0 : 0.5;
}

- (void)dealloc {
    [self stopLockoutTimer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self stopLockoutTimer];
}

@end 