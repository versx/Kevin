//
//  Jarvis__.m
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "Jarvis__.h"

@implementation Jarvis__

static UIC2 *_uic;

static void __attribute__((constructor)) initialize(void) {
    [[Jarvis__ alloc] init];
}

-(id)init
{
    //syslog(@"[INFO] Version: %@", JARVIS_VERSION);
    NSLog(@"[Jarvis] Version: %@", JARVIS_VERSION);
    if ((self = [super init])) {
        NSSetUncaughtExceptionHandler(&onUncaughtException);
        
        _uic = [[UIC2 alloc] init];
        [_uic start];
        //syslog(@"[INFO] started...");
    }
    
    return self;
}

void onUncaughtException(NSException* exception)
{
    syslog(@"[FATAL] %@", exception);
    syslog(@"[FATAL] %@", [NSThread callStackSymbols]);
}

+(void)typeUsername
{
    NSString *username = [[Device sharedInstance] username];
    syslog(@"[DEBUG] typeUsername: %@", username);
    [JarvisTestCase type:username];
    //[JarvisTestCase clearAndType:username];
}

+(void)typePassword
{
    NSString *password = [[Device sharedInstance] password];
    syslog(@"[DEBUG] typePassword: %@", password);
    [JarvisTestCase type:password];
    //[JarvisTestCase clearAndType:password];
}

@end
