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
    NSLog(@"[DeviceState] init");
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
    NSLog(@"[UIC] [Jarvis] Restarting...");
    //UIControl *ui = [[UIControl alloc] init];
    //UIApplication *app = [UIApplication sharedApplication];
    //SEL selector = @selector([NSXPCConnection superclass]:invalidate:);
    //[ui sendAction:selector to:[UIApplication sharedApplication] forEvent:nil];
    // TODO: Restart
    return;
    while (true) { // TODO: Uhh this doesn't look safe. ;-|
        //[[[UIControl alloc] init] sendAction:@selector(NSXPCConnection:invalidate:) to:[UIApplication sharedApplication] forEvent:nil];
        // TODO: UIControl().sendAction(#selector(NSXPCConnection.invalidate) to:UIApplication.shared for:nil);
        [NSThread sleepForTimeInterval:2];
    }
}

+(void)logout
{
    [[Device sharedInstance] setIsLoggedIn:false];
    //_action = nil;
    [[DeviceState sharedInstance] setDelayQuest:false];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"uuid"] = [[Device sharedInstance] uuid];
    dict[@"username"] = [[Device sharedInstance] username];
    dict[@"level"] = [[Device sharedInstance] level];
    dict[@"type"] = @"logged_out";
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:dict
              blocking:true
            completion:^(NSDictionary *result) {}
    ];
    [[Device sharedInstance] setUsername:nil];
    [[Device sharedInstance] setPassword:nil];
    [NSThread sleepForTimeInterval:0.5];
    if ([[Device sharedInstance] username] == nil &&
        [[Settings sharedInstance] enableAccountManager]) {
        NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
        payload[@"uuid"] = [[Device sharedInstance] uuid];
        payload[@"username"] = [[Device sharedInstance] username];
        payload[@"min_level"] = [[Device sharedInstance] minLevel];
        payload[@"max_level"] = [[Device sharedInstance] maxLevel];
        payload[@"type"] = @"get_account";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:payload blocking:true completion:^(NSDictionary *result) {
            NSDictionary *data = dict[@"data"];
            if (data != nil) {
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
                NSLog(@"[UIC] StartupLocation: %@", startupLocation);
                
                NSNumber *firstWarningTimestamp = data[@"first_warning_timestamp"];
                if (firstWarningTimestamp != nil) {
                    NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                    [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
                }
                if (username != nil && ptcToken != nil && ![ptcToken isEqualToString:@""]) {
                    NSLog(@"[UIC] Got token %@ level %@ from backend.", ptcToken, level);
                    NSLog(@"[UIC] Got account %@ level %@ from backend.", username, level);
                    [[Device sharedInstance] setUsername:username];
                    [[Device sharedInstance] setPassword:password];
                    [[Device sharedInstance] setPtcToken:ptcToken];
                    [[Device sharedInstance] setLevel:level];
                    [[Device sharedInstance] setIsLoggedIn:true];
                    [[NSUserDefaults standardUserDefaults] setValue:ptcToken forKey:TOKEN_USER_DEFAULT_KEY];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                } else {
                    NSLog(@"[UIC] [Jarvis] Failed to get account with token. Restarting for normal login.");
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
                NSLog(@"[UIC] [Jarvis] Failed to get account, restarting.");
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
    
    [NSThread sleepForTimeInterval:1];
    [self restart];
}

@end
