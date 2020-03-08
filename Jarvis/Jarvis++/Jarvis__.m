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
    return YES;
}

+(BOOL)findButton:(NSString *)buttonName
{
    // TODO: findButton
    return YES;
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
