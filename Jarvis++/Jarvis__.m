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
        NSSetUncaughtExceptionHandler(&onUncaughtException);
        
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

void onUncaughtException(NSException* exception)
{
    syslog(@"[FATAL] %@", exception);
    syslog(@"[FATAL] %@", [NSThread callStackSymbols]);
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
