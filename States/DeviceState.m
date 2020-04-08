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
        }
    });
}

+(void)logout
{
    [self logout:false];
}

+(void)logout:(BOOL)skipRestart
{
    syslog(@"[INFO] Attempting to logout.");
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    //dispatch_async(dispatch_get_main_queue(), ^{
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
        dict[@"type"] = @"logged_out";
        [Utils postRequest:backendControllerUrl
                      dict:dict
                  blocking:true
                completion:^(NSDictionary *result) {}
        ];
        sleep(1);
        /*
        if ([[[Device sharedInstance] username] isNullOrEmpty] &&
            [[Settings sharedInstance] enableAccountManager]) {
            NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
            payload[@"uuid"] = [[Device sharedInstance] uuid];
            payload[@"username"] = [[Device sharedInstance] username];
            payload[@"min_level"] = [[Device sharedInstance] minLevel];
            payload[@"max_level"] = [[Device sharedInstance] maxLevel];
            payload[@"type"] = @"get_account";
            syslog(@"[DEBUG] Sending get_account request...");
            [Utils postRequest:backendControllerUrl
                          dict:payload
                      blocking:true
                    completion:^(NSDictionary *result) {
                syslog(@"[DEBUG] get_account request: %@", result);
                NSDictionary *data = [result objectForKey:@"data"];
                if (data != nil) {
                    NSString *username = data[@"username"];
                    NSString *password = data[@"password"];
                    NSNumber *level = data[@"level"];
                    NSDictionary *job = data[@"job"];
                    NSNumber *startLat = job[@"lat"];
                    NSNumber *startLon = job[@"lon"];
                    NSNumber *lastLat = data[@"last_encounter_lat"];
                    NSNumber *lastLon = data[@"last_encounter_lon"];
                    NSString *ptcToken = data[@"ptcToken"]; // TODO: Change to ptc_token
                    CLLocation *startupLocation;
                    if (![startLat isEqualToNumber:@0.0] && ![startLon isEqualToNumber:@0.0]) {
                        startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                        [[DeviceState sharedInstance] setStartupLocation:startupLocation];
                    } else if (![lastLat isEqualToNumber:@0.0] && ![lastLon isEqualToNumber:@0.0]) {
                        startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                        [[DeviceState sharedInstance] setStartupLocation:startupLocation];
                    } else {
                        startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                        [[DeviceState sharedInstance] setStartupLocation:startupLocation];
                    }
                
                    [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                    syslog(@"[DEBUG] startupLocation: %@", startupLocation);
                    
                    [self checkWarning:data[@"first_warning_timestamp"]];

                    syslog(@"[DEBUG] Checking if username or ptcToken are empty.");
                    if (![username isNullOrEmpty] && ![ptcToken isNullOrEmpty]) {
                        syslog(@"[INFO] Got account %@ level %@ from backend. ptcToken: %@", username, level, ptcToken);
                        [[Device sharedInstance] setUsername:username];
                        [[Device sharedInstance] setPassword:password];
                        [[Device sharedInstance] setPtcToken:ptcToken];
                        [[Device sharedInstance] setLevel:level];
                        [[Device sharedInstance] setIsLoggedIn:true];
                        if (![ptcToken isNullOrEmpty]) {
                            [[NSUserDefaults standardUserDefaults] setValue:ptcToken forKey:TOKEN_USER_DEFAULT_KEY];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                        }
                    } else {
                        syslog(@"[ERROR] Failed to get account with token. Restarting for normal login.");
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
                        [[Device sharedInstance] setUsername:username];
                        [[Device sharedInstance] setPassword:password];
                        [[Device sharedInstance] setPtcToken:ptcToken];
                        [[Device sharedInstance] setLevel:level];
                        [[Device sharedInstance] setIsLoggedIn:false];
                        [[Device sharedInstance] setShouldExit:true];
                    }
                } else {
                    syslog(@"[ERROR] Failed to get account, restarting.");
                    sleep(1);
                    [[Device sharedInstance] setMinLevel:@0];
                    [[Device sharedInstance] setMaxLevel:@29];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
                    sleep(5);
                    [[Device sharedInstance] setIsLoggedIn:false];
                    [self restart];
                }
            }];
        }
        */
        
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
        
        dispatch_semaphore_signal(sem);
    //});
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
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
