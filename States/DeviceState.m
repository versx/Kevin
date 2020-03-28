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
    syslog(@"[INFO] init");
    if ((self = [super init]))
    {
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
    [lastDeployTime release];
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
        // TODO: Set Defaults? [sharedInstance setDelayQuest:false];
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
@synthesize ultraQuestSpin;
@synthesize newCreated;
@synthesize needsLogout;

@synthesize failedGetJobCount;
@synthesize failedCount;
@synthesize noQuestCount;
@synthesize noItemsCount;
@synthesize spinCount;
@synthesize emptyGmoCount;
@synthesize luckyEggsCount;

@synthesize firstWarningDate;
@synthesize eggStart;
@synthesize lastDeployTime;
@synthesize lastUpdate;

@synthesize lastAction;
@synthesize pokemonEncounterId;
//@synthesize ptcToken;
@synthesize targetFortId;


+(void)restart
{
    syslog(@"[INFO] Restarting...");
    // TODO: Restart
    dispatch_async(dispatch_get_main_queue(), ^{
        while (true) { // REVIEW: Uhh this doesn't look safe. ;-|
            // TODO: UIControl().sendAction(#selector(NSXPCConnection.invalidate) to:UIApplication.shared for:nil);
            UIControl *control = [[UIControl alloc] init];
            UIApplication *app = [UIApplication sharedApplication];
            NSXPCConnection *conn = [NSXPCConnection currentConnection];
            SEL selector = [conn respondsToSelector:@selector(invalidate)];
            [control sendAction:selector
                             to:app
                       forEvent:nil
            ];
        }
    });
}

+(void)logout
{
    syslog(@"[INFO] Attempting to logout.");
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *backendControllerUrl = [[Settings sharedInstance] backendControllerUrl];
        [[Device sharedInstance] setIsLoggedIn:false];
        //_action = nil;
        [[DeviceState sharedInstance] setDelayQuest:false];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"uuid"] = [[Device sharedInstance] uuid];
        dict[@"username"] = [[Device sharedInstance] username];
        dict[@"level"] = [[Device sharedInstance] level];
        dict[@"type"] = @"logged_out";
        [Utils postRequest:backendControllerUrl
                      dict:dict
                  blocking:true
                completion:^(NSDictionary *result) {}
        ];
        [[Device sharedInstance] setUsername:nil];
        [[Device sharedInstance] setPassword:nil];
        [NSThread sleepForTimeInterval:0.5];
        if ([[[Device sharedInstance] username] isNullOrEmpty] &&
            [[Settings sharedInstance] enableAccountManager]) {
            NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
            payload[@"uuid"] = [[Device sharedInstance] uuid];
            payload[@"username"] = [[Device sharedInstance] username];
            payload[@"min_level"] = @1;
            payload[@"max_level"] = @29;
            payload[@"type"] = @"get_account";
            syslog(@"[DEBUG] Sending get_account request...");
            [Utils postRequest:backendControllerUrl
                          dict:payload
                      blocking:true
                    completion:^(NSDictionary *result) {
                syslog(@"[DEBUG] get_account request: %@", result);
                NSDictionary *data = [result objectForKey:@"data"];
                if (data != nil) {
                    syslog(@"[DEBUG] data dictionary: %@", data);
                    NSString *username = data[@"username"];
                    NSString *password = data[@"password"];
                    NSNumber *level = data[@"level"];
                    NSDictionary *job = data[@"job"];
                    NSNumber *startLat = job[@"lat"];
                    NSNumber *startLon = job[@"lon"];
                    NSNumber *lastLat = data[@"last_encounter_lat"];
                    NSNumber *lastLon = data[@"last_encounter_lon"];
                    NSString *ptcToken = data[@"ptcToken"]; // TODO: Change from camel casing.
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
                    syslog(@"[DEBUG] StartupLocation: %@", startupLocation);
                    
                    NSString *firstWarningTimestamp = data[@"first_warning_timestamp"];
                    syslog(@"[DEBUG] firstWarningTimestamp: %@", firstWarningTimestamp);
                    if (firstWarningTimestamp != nil && ![firstWarningTimestamp isEqualToString:@"<null>"]) {
                        NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp ?: 0 doubleValue]];
                        [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
                    }

                    syslog(@"[DEBUG] Checking if username is empty or ptcToken is empty.");
                    if ([username isNullOrEmpty] || [ptcToken isNullOrEmpty]) {
                        syslog(@"[ERROR] Failed to get account with token. Restarting for normal login.");
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
                        [[Device sharedInstance] setUsername:username];
                        [[Device sharedInstance] setPassword:password];
                        [[Device sharedInstance] setPtcToken:ptcToken];
                        [[Device sharedInstance] setLevel:level];
                        [[Device sharedInstance] setIsLoggedIn:false];
                        [[Device sharedInstance] setShouldExit:true];
                    } else {
                        syslog(@"[INFO] Got account %@ level %@ from backend.", username, level);
                        syslog(@"[DEBUG] Got token %@ from backend.", ptcToken);
                        [[Device sharedInstance] setUsername:username];
                        [[Device sharedInstance] setPassword:password];
                        [[Device sharedInstance] setPtcToken:ptcToken];
                        [[Device sharedInstance] setLevel:level];
                        [[Device sharedInstance] setIsLoggedIn:true];
                        if (![ptcToken isNullOrEmpty]) {
                            [[NSUserDefaults standardUserDefaults] setValue:ptcToken forKey:TOKEN_USER_DEFAULT_KEY];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                        }
                    }
                } else {
                    syslog(@"[ERROR] Failed to get account, restarting.");
                    [NSThread sleepForTimeInterval:1];
                    [[Device sharedInstance] setMinLevel:@1]; // Never set to 0 until we can do tutorials.
                    [[Device sharedInstance] setMaxLevel:@29];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
                    [NSThread sleepForTimeInterval:5];
                    [[Device sharedInstance] setIsLoggedIn:false];
                    [self restart];
                }
            }];
        }
        dispatch_semaphore_signal(sem);
    });
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    syslog(@"[DEBUG] Restarting...");
    [NSThread sleepForTimeInterval:1];
    [self restart];
}

@end