//
//  Jarvis__.m
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "Jarvis__.h"

@implementation Jarvis__

static UIC2 *_uic;
static UIImage *_image;

static void __attribute__((constructor)) initialize(void) {
    [[Jarvis__ alloc] init];
}

-(id)init
{
    syslog(@"[INFO] Version: %@", JARVIS_VERSION);
    if ((self = [super init]))
    {
        syslog(@"[INFO] initializing...");
        _uic = [[UIC2 alloc] init];
        [_uic start];
        syslog(@"[INFO] started...");
    }
    
    return self;
}
-(void)dealloc
{
    [_uic release];
    [super dealloc];
}

+(BOOL)clickButton:(NSString *)buttonName
{
    syslog(@"[DEBUG] %@", buttonName);
    // TODO: clickButton
    if ([buttonName isEqualToString:@"BirthYearSelector"]) {
        [JarvisTestCase touch:250 withY:360];
    } else if ([buttonName isEqualToString:@"BirthYear"]) {
        [JarvisTestCase touch:250 withY:520];
    } else if ([buttonName isEqualToString:@"SubmitButton"]) {
        [JarvisTestCase touch:220 withY:400];
    } else if ([buttonName isEqualToString:@"NewPlayerButton"]) {
        [JarvisTestCase touch:250 withY:400];
    } else if ([buttonName isEqualToString:@"TrainerClubButton"]) {
        [JarvisTestCase touch:250 withY:360];
    } else if ([buttonName isEqualToString:@"UsernameButton"]) {
        [JarvisTestCase touch:250 withY:250];
    } else if ([buttonName isEqualToString:@"PasswordButton"]) {
        [JarvisTestCase touch:250 withY:290];
    } else if ([buttonName isEqualToString:@"SignInButton"]) {
        [JarvisTestCase touch:250 withY:340];
    } else if ([buttonName isEqualToString:@"TrackerButton"]) {
        [JarvisTestCase touch:320 withY:800]; // TODO: TrackerButton
    }
    return true;
}

/*
-(void)isButtonExistsWithCompletionHandler:(void(^)(BOOL exists)) completion
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        bool result = true;
        completion(result);
    });
}
 */

+(BOOL)isBirthYear:(NSDictionary *)color
{
    bool result = false;
    syslog(@"[DEBUG] Checking birth year selector pixel: color=%@", color);
    if ([color[@"red"] isEqual:@0.0313725508749485] &&
        [color[@"green"] isEqual:@0.7960784435272217] &&
        [color[@"blue"] isEqual:@1] &&
        [color[@"alpha"] isEqual:@1]) {
        syslog(@"[DEBUG] Found birth year selector button");
        result = true;
    }
    return result;
}

+(BOOL)isSubmit:(NSDictionary *)color
{
    bool result = false;
    syslog(@"[DEBUG] Checking submit button pixel: color=%@", color);
    if ([color[@"red"] isEqual:@0.0313725508749485] &&
        [color[@"green"] isEqual:@0.7960784435272217] &&
        [color[@"blue"] isEqual:@1] &&
        [color[@"alpha"] isEqual:@1]) {
        syslog(@"[DEBUG] Found submit button");
        result = true;
    }
    return result;
}

+(BOOL)isMenuButton:(NSDictionary *)color
{
    bool result = false;
    syslog(@"[DEBUG] Checking menu button pixel: color=%@", color);
    if ([color[@"red"] isEqual:@0.7490196228027344] && //0.6666666865348816
        [color[@"green"] isEqual:@0.9490196108818054] && //0.4980392158031464
        [color[@"blue"] isEqual:@0.1568627506494522] && //0.1137254908680916
        [color[@"alpha"] isEqual:@1]) {
        syslog(@"[DEBUG] Found pokeball menu button");
        result = true;
    }
    return result;
}

+(BOOL)isMenuCloseButton:(NSDictionary *)color
{
    bool result = false;
    syslog(@"[DEBUG] Checking menu close button pixel: color=%@", color);
    if ([color[@"red"] isEqual:@0.9254902005195618] &&
        [color[@"green"] isEqual:@0.9803921580314636] &&
        [color[@"blue"] isEqual:@0.9137254953384399] &&
        [color[@"alpha"] isEqual:@1]) {
        syslog(@"[DEBUG] Found close pokeball menu button");
        result = true;
    }
    return result;
}

+(BOOL)isDifferentAccountButton:(NSDictionary *)color
{
    bool result = false;
    syslog(@"[DEBUG] Checking different account button pixel: color=%@", color);
    if ([color[@"red"] isEqual:@0.5058823823928833] &&
        [color[@"green"] isEqual:@0.6549019813537598] &&
        [color[@"blue"] isEqual:@0.2666666805744171] &&
        [color[@"alpha"] isEqual:@1]) {
        syslog(@"[DEBUG] Found submit button");
        result = true;
    }
    return result;
}

+(BOOL)isRetryButton:(NSDictionary *)color
{
    bool result = false;
    syslog(@"[DEBUG] Checking retry button pixel: color=%@", color);
    /*
    if ([color[@"red"] isEqual:@0.9254902005195618] &&
        [color[@"green"] isEqual:@0.9803921580314636] &&
        [color[@"blue"] isEqual:@0.9137254953384399] &&
        [color[@"alpha"] isEqual:@1]) {
        syslog(@"[DEBUG] Found submit button");
        result = true;
    }
    */
    return result;
}

// TODO: Unused
+(BOOL)isFailedToLoginScreen:(NSDictionary *)color
{
    syslog(@"[DEBUG] Checking for failed to login pop-up pixel: color=%@", color);
    double red = [color[@"red"] doubleValue];
    double green = [color[@"green"] doubleValue];
    double blue = [color[@"blue"] doubleValue];
    if (red >= 0.39 && red <= 0.49 &&
        green >= 0.75 && green <= 0.90 &&
        blue >= 0.55 && blue <= 0.70) {
        return true;
    }
    return false;
}

+(BOOL)isPassengerButton:(NSDictionary *)color
{
    bool result = false;
    syslog(@"[DEBUG] Checking passenger button pixel: color=%@", color);
    /*
    if ([color[@"red"] isEqual:@0.9254902005195618] &&
        [color[@"green"] isEqual:@0.9803921580314636] &&
        [color[@"blue"] isEqual:@0.9137254953384399] &&
        [color[@"alpha"] isEqual:@1]) {
        syslog(@"[DEBUG] Found submit button");
        result = true;
    }
    */
    return result;
}

+(BOOL)findButton:(NSString *)buttonName
{
    // TODO: Finish findButton
    syslog(@"[DEBUG] findButton: %@", buttonName);
    bool result = false;
    _image = [Utils takeScreenshot];
    if ([buttonName isEqualToString:@"BirthYearSelector"]) {
        NSDictionary *color = [_image rgbAtLocation:250 withY:360];
        result = [Jarvis__ isBirthYear:color];
    } else if ([buttonName isEqualToString:@"SubmitButton"]) {
        NSDictionary *color = [_image rgbAtLocation:220 withY:400];
        result = [Jarvis__ isSubmit:color];
    } else if ([buttonName isEqualToString:@"NewPlayerButton"]) {
        UIColor *color = [_image getPixelColor:400 withY:820];
        [Utils touch:250 withY:400];
        syslog(@"[DEBUG] %@ Pixel Color: %@", buttonName, color);
    } else if ([buttonName isEqualToString:@"TrainerClubButton"]) {
        UIColor *color = [_image getPixelColor:320 withY:800];
        syslog(@"[DEBUG] %@ Pixel Color: %@", buttonName, color);
        [Utils touch:250 withY:360];
    } else if ([buttonName isEqualToString:@"UsernameButton"]) {
        UIColor *color = [_image getPixelColor:320 withY:500];
        syslog(@"[DEBUG] %@ Pixel Color: %@", buttonName, color);
        [Utils touch:250 withY:250];
    } else if ([buttonName isEqualToString:@"PasswordButton"]) {
        UIColor *color = [_image getPixelColor:320 withY:600];
        syslog(@"[DEBUG] %@ Pixel Color: %@", buttonName, color);
        [Utils touch:250 withY:290];
    } else if ([buttonName isEqualToString:@"SignInButton"]) {
        UIColor *color = [_image getPixelColor:375 withY:680];
        syslog(@"[DEBUG] %@ Pixel Color: %@", buttonName, color);
        [Utils touch:250 withY:340];
    } else if ([buttonName isEqualToString:@"TrackerButton"]) {
        UIColor *color = [_image getPixelColor:320 withY:800];
        syslog(@"[DEBUG] %@ Pixel Color: %@", buttonName, color);
    }
    NSLog(@"[DEBUG] findButton Result: %s", result ? "Yes" : "No");
    return result;
}

+(NSString *)getMenuButton
{
    // TODO: Finish getMenuButton
    syslog(@"[DEBUG] getMenuButton");
    @try {
        _image = [Utils takeScreenshot];
        if ([Jarvis__ isMenuButton:[_image rgbAtLocation:180 withY:540]]) {
            return @"MenuButton";
        } else if ([Jarvis__ isMenuCloseButton:[_image rgbAtLocation:180 withY:540]]) {
            //return @"MenuCloseButton";
            return @"MenuButton";
        } else if ([Jarvis__ isDifferentAccountButton:[_image rgbAtLocation:220 withY:350]]) {
            return @"DifferentAccountButton";
        }
    }
    @catch (NSException *exception) {
        syslog(@"[ERROR] getMenuButton: %@", exception);
    }
    return @"";
}

+(BOOL)eggDeploy
{
    syslog(@"[DEBUG] eggDeploy");
    // TODO: EggDeploy
    return false;
}

+(BOOL)getToMainScreen
{
    syslog(@"[DEBUG] getToMainScreen");
    // TODO: getToMainScreen
    return false;
}

+(void)typeUsername
{
    NSString *username = [[Device sharedInstance] username];
    syslog(@"[DEBUG] typeUsername: %@", username);
    [JarvisTestCase type:username];
}

+(void)typePassword
{
    NSString *password = [[Device sharedInstance] password];
    syslog(@"[DEBUG] typePassword: %@", password);
    [JarvisTestCase type:password];
}

@end
