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
    NSLog(@"[Jarvis] init Version: %@", JARVIS_VERSION);
    if ((self = [super init]))
    {
        NSLog(@"[Jarvis] initializing...");
        _uic = [[UIC2 alloc] init];
        [_uic start];
        NSLog(@"[Jarvis] started...");
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
    NSLog(@"[Jarvis] clickButton: %@", buttonName);
    // TODO: clickButton
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            _image = [Utils takeScreenshot];
            NSLog(@"[Jarvis] Took screenshot to check for pixel coord for button %@...", buttonName);
            if ([buttonName isEqualToString:@"NewPlayerButton"]) {
                UIColor *color = [_image getPixelColor:400 withY:820];
                [Utils touch:250 withY:400];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
            } else if ([buttonName isEqualToString:@"TrainerClubButton"]) {
                UIColor *color = [_image getPixelColor:320 withY:800];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
                [Utils touch:250 withY:360];
            } else if ([buttonName isEqualToString:@"UsernameButton"]) {
                UIColor *color = [_image getPixelColor:320 withY:500];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
                [Utils touch:250 withY:250];
            } else if ([buttonName isEqualToString:@"PasswordButton"]) {
                UIColor *color = [_image getPixelColor:320 withY:600];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
                [Utils touch:250 withY:290];
            } else if ([buttonName isEqualToString:@"SignInButton"]) {
                UIColor *color = [_image getPixelColor:375 withY:680];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
                [Utils touch:250 withY:340];
            } else if ([buttonName isEqualToString:@"TrackerButton"]) {
                UIColor *color = [_image getPixelColor:320 withY:800];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
            }
        }
    });
    return true;
}

+(BOOL)findButton:(NSString *)buttonName
{
    NSLog(@"[Jarvis] findButton: %@", buttonName);
    // TODO: findButton
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            _image = [Utils takeScreenshot];
            NSLog(@"[Jarvis] Took screenshot to check for pixel coord for button %@...", buttonName);
            if ([buttonName isEqualToString:@"NewPlayerButton"]) {
                UIColor *color = [_image getPixelColor:400 withY:820];
                [Utils touch:250 withY:400];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
            } else if ([buttonName isEqualToString:@"TrainerClubButton"]) {
                UIColor *color = [_image getPixelColor:320 withY:800];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
                [Utils touch:250 withY:360];
            } else if ([buttonName isEqualToString:@"UsernameButton"]) {
                UIColor *color = [_image getPixelColor:320 withY:500];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
                [Utils touch:250 withY:250];
            } else if ([buttonName isEqualToString:@"PasswordButton"]) {
                UIColor *color = [_image getPixelColor:320 withY:600];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
                [Utils touch:250 withY:290];
            } else if ([buttonName isEqualToString:@"SignInButton"]) {
                UIColor *color = [_image getPixelColor:375 withY:680];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
                [Utils touch:250 withY:340];
            } else if ([buttonName isEqualToString:@"TrackerButton"]) {
                UIColor *color = [_image getPixelColor:320 withY:800];
                NSLog(@"[Jarvis] %@ Pixel Color: %@", buttonName, color);
            }
        }
    });
    return true;
}

+(NSString *)getMenuButton
{
    NSLog(@"[Jarvis] getMenuButton");
    // TODO: getMenuButton
    return @"";
}

+(BOOL)eggDeploy
{
    NSLog(@"[Jarvis] eggDeploy");
    // TODO: EggDeploy
    return false;
}

+(BOOL)getToMainScreen
{
    NSLog(@"[Jarvis] getToMainScreen");
    // TODO: getToMainScreen
    return false;
}

@end
