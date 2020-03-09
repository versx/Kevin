//
//  Jarvis__.m
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "Jarvis__.h"

@implementation Jarvis__

static UIC2 *_uic;

-(id)init
{
    NSLog(@"[Jarvis] init");
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
    // TODO: clickButton
    if ([buttonName isEqualToString:@"NewPlayerButton"]) {
    } else if ([buttonName isEqualToString:@"TrainerClubButton"]) {
    } else if ([buttonName isEqualToString:@"NewPlayerButton"]) {
    } else if ([buttonName isEqualToString:@"UsernameButton"]) {
    } else if ([buttonName isEqualToString:@"PasswordButton"]) {
    } else if ([buttonName isEqualToString:@"SignInButton"]) {
    } else if ([buttonName isEqualToString:@"TrackerButton"]) {
    }
    return true;
}

+(BOOL)findButton:(NSString *)buttonName
{
    // TODO: findButton
    if ([buttonName isEqualToString:@"NewPlayerButton"]) {
    } else if ([buttonName isEqualToString:@"TrainerClubButton"]) {
    } else if ([buttonName isEqualToString:@"NewPlayerButton"]) {
    } else if ([buttonName isEqualToString:@"UsernameButton"]) {
    } else if ([buttonName isEqualToString:@"PasswordButton"]) {
    } else if ([buttonName isEqualToString:@"SignInButton"]) {
    } else if ([buttonName isEqualToString:@"TrackerButton"]) {
    }
    return true;
}

+(NSString *)getMenuButton
{
    // TODO: getMenuButton
    return @"";
}

+(BOOL)eggDeploy
{
    // TODO: EggDeploy
    return false;
}

+(BOOL)getToMainScreen
{
    // TODO: getToMainScreen
    return false;
}

@end
