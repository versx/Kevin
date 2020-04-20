//
//  DeviceState.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "DeviceState.h"

@implementation DeviceState

-(id)init
{
    if ((self = [super init])) {
        lastAction = @"";
        spinCount = @0;
        failedCount = @0;
        failedGetJobCount = @0;
        emptyGmoCount = @0;
        noQuestCount = @0;
        noItemsCount = @0;
        eggStart = [NSDate date];
    }
    return self;
}

-(void)dealloc
{
    [currentLocation release];
    [startupLocation release];
    [lastLocation release];
    [lastQuestLocation release];
    [firstWarningDate release];
    [eggStart release];
    [lastUpdate release];
    [pokemonEncounterId release];
    [targetFortId release];
    
    [super dealloc];
}

+(DeviceState *)sharedInstance
{
    static DeviceState *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DeviceState alloc] init];
        [sharedInstance setLastUpdate:[NSDate date]];
    });
    return sharedInstance;
}

@synthesize currentLocation;
@synthesize startupLocation;
@synthesize lastLocation;
@synthesize lastQuestLocation;

@synthesize gotIV;
@synthesize gotQuest;
@synthesize gotQuestEarly;
@synthesize gotItems;
@synthesize waitForData;
@synthesize waitRequiresPokemon;
@synthesize delayQuest;
@synthesize skipSpin;
@synthesize isQuestInit;
@synthesize newCreated;
@synthesize needsLogout;
@synthesize isStartup;

@synthesize failedGetJobCount;
@synthesize failedCount;
@synthesize noQuestCount;
@synthesize noItemsCount;
@synthesize spinCount;
@synthesize emptyGmoCount;

@synthesize firstWarningDate;
@synthesize eggStart;
@synthesize lastUpdate;

@synthesize lastAction;
@synthesize pokemonEncounterId;
@synthesize targetFortId;


+(void)restart
{
    syslog(@"[INFO] Restarting...");
    dispatch_async(dispatch_get_main_queue(), ^{
        while (true) { // REVIEW: Uhh this doesn't look safe. ;-|
            SEL selector = [[NSXPCConnection currentConnection] respondsToSelector:@selector(invalidate)];
            [[[UIControl alloc] init] sendAction:selector
                                              to:[UIApplication sharedApplication]
                                        forEvent:nil
            ];
            sleep(2);
        }
    });
}

+(void)logout
{
    [self logout:false];
}

+(void)logout:(bool)skipRestart
{
    syslog(@"[INFO] Attempting to logout.");
    NSString *oldUsername = [[Device sharedInstance] username];
    [[Device sharedInstance] setIsLoggedIn:false];
    [[Device sharedInstance] setUsername:nil];
    [[Device sharedInstance] setPassword:nil];
    [[Device sharedInstance] setLuckyEggsCount:@0];
    [[Device sharedInstance] setLastEggDeployTime:nil];
    [[DeviceState sharedInstance] setDelayQuest:false];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSString *backendControllerUrl = [[Settings sharedInstance] backendControllerUrl];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"uuid"] = [[Device sharedInstance] uuid];
    dict[@"username"] = oldUsername;
    dict[@"level"] = [[Device sharedInstance] level];
    dict[@"type"] = TYPE_LOGGED_OUT;
    [Utils postRequest:backendControllerUrl
                  dict:dict
              blocking:true
            completion:^(NSDictionary *result) {}
    ];
    sleep(1);
    
    [[Device sharedInstance] setIsLoggedIn:false];
    [[Device sharedInstance] setUsername:nil];
    [[Device sharedInstance] setPassword:nil];
    [[Device sharedInstance] setLuckyEggsCount:@0];
    [[Device sharedInstance] setLastEggDeployTime:nil];
    [[DeviceState sharedInstance] setDelayQuest:false];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:TOKEN_USER_DEFAULT_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (!skipRestart) {
        syslog(@"[DEBUG] Restarting...");
        sleep(1);
        [self restart];
    }
}

+(void)checkWarning:(NSString *)timestamp
{
    NSString *firstWarningTimestamp = timestamp;
    if (firstWarningTimestamp != (id)[NSNull null]) {
        NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp ?: 0 intValue]];
        syslog(@"[DEBUG] firstWarningDate: %@", firstWarningDate);
        [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
    }
}

@end
