//
//  UIC.cpp
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "UIC.h"
//#import <XCTest/XCTest.h>
//@import XCTest;

//using namespace std;

// TODO: Remote config
// TODO: KIF library
// TODO: StateManager class
// TODO: Pixel checks
// TODO: CocoaPods

#pragma mark Global Variables

static NSString *TokenUserDefaultsKey = @"5750bac0-483c-4131-80fd-6b047b2ca7b4";
static NSString *LoginUserDefaultsKey = @"60b01025-clea-422c-9b0e-d70bf489de7f";

static BOOL _firststart = true;
static BOOL _startup = true;
//static BOOL _started = false;
//static CLLocation *_currentLocation;
//static BOOL _waitRequiresPokemon = false;
//static BOOL _waitForData = false;
//static NSLock *_lock = [[NSLock alloc] init];
//static NSDate *_firstWarningDate;
static NSNumber *_jitterCorner = @0;
//static BOOL _gotQuest = false;
//static BOOL _gotIV = false;
static NSNumber *_noQuestCount = @0;
static NSNumber *_noEncounterCount = @0;
static NSNumber *_emptyGmoCount = @0;
static NSString *_pokemonEncounterId;
static NSString *_action;
static NSNumber *_encounterDistance = @0.0;
//static NSNumber *_encounterDelay = @0.0;
//static UIImage *_image;
static NSString *_ptcToken = [[NSUserDefaults standardUserDefaults] valueForKey:TokenUserDefaultsKey];

// Button Detection
static BOOL _menuButton = false;
//static BOOL _menuButton2 = false;
static NSString *_neededButton = @"";
//static BOOL _okButton = false;
static BOOL _newPlayerButton = false;
static BOOL _bannedScreen = false;
static BOOL _invalidScreen = false;

static NSNumber *_failedGetJobCount;
static NSNumber *_failedCount;

static CLLocation *_startupLocation;
static NSDate *_lastUpdate = [NSDate date];
static BOOL _delayQuest = false;
static BOOL _gotQuestEarly = false;

// Mizu Leveling
static BOOL _isQuestInit = false;
static NSString *_targetFortId;
static CLLocation *_lastQuestLocation;
//static CLLocation *_lastLocation;
static BOOL _gotItems = false;
static NSNumber *_noItemsCount = @0;
static BOOL _skipSpin = false;
static NSNumber *_luckyEggsNum = @0;
static NSDate *_lastDeployTime = [NSDate date];
static NSNumber *_spins = @401;
static BOOL _ultraQuestSpin = false;

// TODO: UIC properties
//static BOOL _newLogIn;
static BOOL _newCreated;
static BOOL _needsLogout;
static NSDate *_eggStart;

@implementation UIC2

static HttpServer *_httpServer;
static JobController *_jobController;

#pragma mark Constructor/Deconstructor

-(id)init
{
    NSLog(@"[UIC] init");
    if ((self = [super init]))
    {
    }
    
    return self;
}

-(void)dealloc
{
    [_httpServer release];
    [super dealloc];
}

#pragma App Management

-(void)start
{
    NSLog(@"[UIC] start");
    NSLog(@"-----------------------------");
    NSLog(@"[UIC] Device Uuid: %@", [[Device sharedInstance] uuid]);
    NSLog(@"[UIC] Device Model: %@", [[Device sharedInstance] model]);
    NSLog(@"[UIC] Device OS: %@", [[Device sharedInstance] osName]);
    NSLog(@"[UIC] Device OS Version: %@", [[Device sharedInstance] osVersion]);
    NSLog(@"-----------------------------");
    [[Settings sharedInstance] config];
    
    //UIColor *color = [Utils getPixelColor:0 withY:0];
    //NSLog(@"[UIC] PixelColor: %@", color);
    
    //NSLog(@"Testing RESTART in 3 seconds...");
    //[NSThread sleepForTimeInterval:3];
    //[self restart];
    
    _jobController = [[JobController alloc] init];
    
    _httpServer = [[HttpServer alloc] init];
    _httpServer.delegate = self;
    [_httpServer listen];

    [self startHeatbeatLoop];
    
    // TODO: [self startUicLoop];
}

-(void)startHeatbeatLoop
{
    bool heatbeatRunning = true;
    NSLog(@"[UIC] Starting heatbeat dispatch queue...");
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    data[@"uuid"] = [[Device sharedInstance] uuid];
    data[@"username"] = [[Device sharedInstance] username];
    data[@"type"] = @"heartbeat";
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:data blocking:false completion:^(NSDictionary *result) {}];
    dispatch_queue_t heatbeatQueue = dispatch_queue_create("heatbeat_queue", NULL);
    dispatch_async(heatbeatQueue, ^{
        while (heatbeatRunning) {
            // Check if time since last checking was within 2 minutes, if not reboot device.
            [NSThread sleepForTimeInterval:15];
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:_lastUpdate];
            if (timeIntervalSince >= 120) {
                NSLog(@"[UIC] [Jarvis] HTTP SERVER DIED. Restarting...");
                [self restart];
            } else {
                NSLog(@"[UIC] Last data %f We Good", timeIntervalSince);
            }
        }
        
        // Force stop HTTP listener to prevent binding issues.
        NSLog(@"[UIC] Force-stopping HTTP server.");
        [_httpServer stop];
    });
    //dispatch_release(heatbeatQueue);
}

-(void)startUicLoop
{
    NSLog(@"[UIC] startUicLoop");
    _eggStart = [[NSDate date] initWithTimeInterval:-1860 sinceDate:[NSDate date]];
    // Init AI
    //initJarvis();
    
    NSLog(@"[UIC] Running on %@ delay set to %@",
          [[Device sharedInstance] model],
          [[Device sharedInstance] multiplier]
    );
    [self loginStateHandler];
}

-(void)restart
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

-(void)logout
{
    [[Device sharedInstance] setIsLoggedIn:false];
    //_action = nil;
    _delayQuest = false;
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"uuid"] = [[Device sharedInstance] uuid];
    dict[@"username"] = [[Device sharedInstance] username];
    dict[@"level"] = [[Device sharedInstance] level];
    dict[@"type"] = @"logged_out";
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:dict blocking:true completion:^(NSDictionary *result) {}];
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
            NSDictionary *data = [dict objectForKey:@"data"];
            if (data != nil) {
                NSString *username = [data objectForKey:@"username"];
                NSString *password = [data objectForKey:@"password"];
                NSNumber *level = [data objectForKey:@"level"];
                NSDictionary *job = [data objectForKey:@"job"];
                NSNumber *startLat = [job objectForKey:@"lat"];
                NSNumber *startLon = [job objectForKey:@"lon"];
                NSNumber *lastLat = [data objectForKey:@"last_encounter_lat"];
                NSNumber *lastLon = [data objectForKey:@"last_encounter_lon"];
                NSString *ptcToken = [data objectForKey:@"ptcToken"]; // TODO: Change from camel casing.
                if (![startLat isEqualToNumber:@0.0] && ![startLon isEqualToNumber:@0.0]) {
                    _startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                } else if (![lastLat isEqualToNumber:@0.0] && ![lastLon isEqualToNumber:@0.0]) {
                    _startupLocation = [Utils createCoordinate:[lastLat doubleValue] lon:[lastLon doubleValue]];
                } else {
                    _startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                }
            
                CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                NSLog(@"[UIC] StartupLocation: %@", _startupLocation);
                
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
                    [[NSUserDefaults standardUserDefaults] setValue:ptcToken forKey:TokenUserDefaultsKey];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                } else {
                    NSLog(@"[UIC] [Jarvis] Failed to get account with token. Restarting for normal login.");
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LoginUserDefaultsKey];
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
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:LoginUserDefaultsKey];
                [NSThread sleepForTimeInterval:5];
                [[Device sharedInstance] setIsLoggedIn:false];
                [self restart];
            }
        }];
    }
    
    [NSThread sleepForTimeInterval:1];
    [self restart];
}


#pragma mark State Managers

-(void *)loginStateHandler
{
    dispatch_queue_t loginStateQueue = dispatch_queue_create("login_state_queue", NULL);
    dispatch_async(loginStateQueue, ^{
        NSNumber *startupCount = @0;
        while (_startup) {
            if (!_firststart) {
                NSLog(@"[UIC] [Jarvis] App still in startup...");
                while (!_menuButton) {
                    _newPlayerButton = [self clickButton:@"NewPlayerButton"];
                    if (_newPlayerButton) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TokenUserDefaultsKey];
                        _newPlayerButton = false;
                        NSLog(@"[UIC] [Jarvis] Started at Login Screen");
                        [NSThread sleepForTimeInterval:1];
                        bool ptcButton = false;
                        NSNumber *ptcTryCount = @0;
                        while (!ptcButton) {
                            ptcButton = [self clickButton:@"TrainerClubButton"];
                            ptcTryCount = [Utils incrementInt:ptcTryCount];
                            if ([ptcTryCount intValue] > 10) {
                                _newPlayerButton = [self clickButton:@"NewPlayerButton"];
                                ptcTryCount = @0;
                            }
                            [NSThread sleepForTimeInterval:1];
                        }
                        
                        bool usernameButton = false;
                        while (!usernameButton) {
                            usernameButton = [self clickButton:@"UsernameButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        // TODO: typeUsername();
                        [NSThread sleepForTimeInterval:1];
                        
                        bool passwordButton = false;
                        while (!passwordButton) {
                            passwordButton = [self clickButton:@"PasswordButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        // TODO: typePassword();
                        [NSThread sleepForTimeInterval:1];
                        
                        // TODO: touchAtPoint(180, 100);
                        [NSThread sleepForTimeInterval:1];
                        
                        bool signinButton = false;
                        while (!signinButton) {
                            signinButton = [self clickButton:@"SignInButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        
                        NSNumber *delayMultiplier = [[Device sharedInstance] multiplier];
                        NSNumber *sleep = @([delayMultiplier intValue] + 15);
                        [NSThread sleepForTimeInterval:[sleep intValue]];
                    }
                    
                    _bannedScreen = [self findButton:@"BannedScreen"];
                    if (_bannedScreen) {
                        _bannedScreen = false;
                        NSLog(@"[UIC] [Jarvis] Account banned, switching accounts.");
                        NSLog(@"[UIC] [Jarvis] Username: %@", [[Device sharedInstance] username]);
                        NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
                        data[@"uuid"] = [[Device sharedInstance] uuid];
                        data[@"username"] = [[Device sharedInstance] username];
                        data[@"type"] = @"account_banned";
                        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:data blocking:true completion:^(NSDictionary *result) {}];
                        [self logout];
                    }
                    
                    _invalidScreen = [self findButton:@"WrongUser"];
                    if (_invalidScreen) {
                        _invalidScreen = false;
                        NSLog(@"[UIC] [Jarvis] Wrong username, switching accounts.");
                        NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
                        data[@"uuid"] = [[Device sharedInstance] uuid];
                        data[@"username"] = [[Device sharedInstance] username];
                        data[@"type"] = @"account_banned"; // TODO: Uhhh should be account_invalid_credentials no?
                        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:data blocking:true completion:^(NSDictionary *result) {}];
                        [self logout];
                    }
                    
                    _neededButton = [self getMenuButton];
                    if ([_neededButton isEqualToString:@"DifferentAccountButton"]) {
                        NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
                        data[@"uuid"] = [[Device sharedInstance] uuid];
                        data[@"username"] = [[Device sharedInstance] username];
                        data[@"type"] = @"account_invalid_credentials";
                        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:data blocking:true completion:^(NSDictionary *result) {}];
                        [self logout];
                    }
                    
                    if ([_neededButton isEqualToString:@"MenuButton"]) {
                        _menuButton = true;
                    }
                    
                    [NSThread sleepForTimeInterval:5];
                    if ([startupCount intValue] > 10) {
                        NSLog(@"[UIC] [Jarvis] Stuck somewhere logging out and restarting...");
                        [self logout];
                    }
                    startupCount = [Utils incrementInt:startupCount];
                }
                
                [NSThread sleepForTimeInterval:1];
                NSMutableDictionary *tokenData = [[NSMutableDictionary alloc] init];
                tokenData[@"uuid"] = [[Device sharedInstance] uuid];
                tokenData[@"username"] = [[Device sharedInstance] username];
                tokenData[@"ptcToken"] = _ptcToken;
                tokenData[@"type"] = @"ptcToken";
                [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:tokenData blocking:true completion:^(NSDictionary *result) {}];
                NSLog(@"[UIC] [Jarvis] App in Main Screen stopping detection.");
                [self clickButton:@"TrackerButton"];
                _startup = false;
            } else {
                [NSThread sleepForTimeInterval:10];
                _firststart = false;
            }
        }
    });
    //dispatch_release(loginStateQueue);
    return 0;
}

-(void *)gameStateHandler
{
    // TODO: qos: background dispatch
    dispatch_queue_t gameStateQueue = dispatch_queue_create("game_state_queue", NULL);
    dispatch_async(gameStateQueue, ^{
        bool hasWarning = false;
        _failedGetJobCount = 0;
        _failedCount = 0;
        _emptyGmoCount = 0;
        _noEncounterCount = 0;
        _noQuestCount = 0;
        
        NSMutableDictionary *initData = [[NSMutableDictionary alloc] init];
        initData[@"uuid"] = [[Device sharedInstance] uuid];
        initData[@"username"] = [[Device sharedInstance] username];
        initData[@"type"] = @"init";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:initData blocking:true completion:^(NSDictionary *result) {
            if (result == nil) {
                NSLog(@"[UIC] Failed to connect to backend!");
                [NSThread sleepForTimeInterval:5];
                [self restart];
            } else if (![([result objectForKey:@"status"] ?: @"fail") isEqualToString:@"ok"]) {
                NSString *error = [result objectForKey:@"error"] ?: @"? (No error sent)";
                NSLog(@"[UIC] Backend returned error: %@", error);
                [[Device sharedInstance] setShouldExit:true];
            }
            
            NSDictionary *data = [result objectForKey:@"data"];
            if (data == nil) {
                NSLog(@"[UIC] Backend did not include data in response.");
                [[Device sharedInstance] setShouldExit:true];
            }
            
            if (!([data objectForKey:@"assigned"] ?: false)) {
                NSLog(@"[UIC] Device is not assigned to an instance!");
                [[Device sharedInstance] setShouldExit:true];
            }
            
            NSNumber *firstWarningTimestamp = [data objectForKey:@"first_warning_timestamp"];
            if (firstWarningTimestamp != nil) {
                NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
            }
            
            NSLog(@"[UIC] Connected to backend successfully!");
            [[Device sharedInstance] setShouldExit:false];
        }];
        
        if ([[Device sharedInstance] shouldExit]) {
            [[Device sharedInstance] setShouldExit:false];
            [NSThread sleepForTimeInterval:5];
            [self restart];
        }
        
        if (([[Device sharedInstance] username] == nil ||
             [[[Device sharedInstance] username] isEqualToString:@"fail"]) &&
             [[Settings sharedInstance] enableAccountManager]) {
            NSMutableDictionary *getAccountData = [[NSMutableDictionary alloc] init];
            getAccountData[@"uuid"] = [[Device sharedInstance] uuid];
            getAccountData[@"username"] = [[Device sharedInstance] username];
            getAccountData[@"min_level"] = [[Device sharedInstance] minLevel];
            getAccountData[@"max_level"] = [[Device sharedInstance] maxLevel];
            getAccountData[@"type"] = @"get_account";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:getAccountData blocking:true completion:^(NSDictionary *result) {
                NSDictionary *data = [result objectForKey:@"data"];
                if (data != nil) {
                    NSString *username = [data objectForKey:@"username"];
                    NSString *password = [data objectForKey:@"password"];
                    NSNumber *level = [data objectForKey:@"level"];
                    NSDictionary *job = [data objectForKey:@"job"];
                    NSNumber *startLat = [job objectForKey:@"lat"];
                    NSNumber *startLon = [job objectForKey:@"lon"];
                    NSNumber *lastLat = [data objectForKey:@"last_encounter_lat"];
                    NSNumber *lastLon = [data objectForKey:@"last_encounter_lon"];
                    
                    if (username != nil) {
                        NSLog(@"[UIC] Got account %@ level %@ from backend.", username, level);
                    } else {
                        NSLog(@"[UIC] Failed to get account and not logged in.");
                        [[Device sharedInstance] setShouldExit:true];
                    }
                    [[Device sharedInstance] setUsername:username];
                    [[Device sharedInstance] setPassword:password];
                    [[Device sharedInstance] setLevel:level];
                    [[Device sharedInstance] setIsLoggedIn:false];
                    if ([startLat doubleValue] != 0.0 && [startLon doubleValue] != 0.0) {
                        _startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                    } else if ([lastLat doubleValue] != 0.0 && [lastLon doubleValue] != 0.0) {
                        _startupLocation = [Utils createCoordinate:[lastLat doubleValue] lon:[lastLon doubleValue]];
                    } else {
                        _startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                    }
                    CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                    [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                    NSLog(@"[UIC] StartupLocation: %@", _startupLocation);
                    NSNumber *firstWarningTimestamp = [data objectForKey:@"first_warning_timestamp"];
                    if (firstWarningTimestamp != nil) {
                        NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                        [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
                    }
                } else {
                    NSLog(@"[UIC] Failed to get account and not logged in.");
                    [[Device sharedInstance] setMinLevel:@1]; // Never set to 0 until we can complete tutorials.
                    [[Device sharedInstance] setMaxLevel:@29];
                    [NSThread sleepForTimeInterval:1];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LoginUserDefaultsKey];
                    [NSThread sleepForTimeInterval:5];
                    [[Device sharedInstance] setIsLoggedIn:false];
                    [self restart];
                }
            }];
        }
        
        while (![[Device sharedInstance] shouldExit]) {
            while (!_startup) {
                if (_needsLogout) {
                    //self.lock.lock();
                    CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                    [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                    //self.lock.unlock();
                    [self logout];
                }
                NSMutableDictionary *getJobData = [[NSMutableDictionary alloc] init];
                getJobData[@"uuid"] = [[Device sharedInstance] uuid];
                getJobData[@"username"] = [[Device sharedInstance] username];
                getJobData[@"type"] = @"get_job";
                [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:getJobData blocking:true completion:^(NSDictionary *result) {
                    if (result == nil) {
                        if ([_failedGetJobCount intValue] == 10) {
                            NSLog(@"[UIC] Failed to get job 10 times in a row. Exiting...");
                            [[Device sharedInstance] setShouldExit:true];
                        } else {
                            NSLog(@"[UIC] Failed to get a job.");
                        }
                    } else if ([[Settings sharedInstance] enableAccountManager]) {
                        NSDictionary *data = [result objectForKey:@"data"];
                        if (data != nil) {
                            NSNumber *minLevel = [data objectForKey:@"min_level"];
                            NSNumber *maxLevel = [data objectForKey:@"max_level"];
                            [[Device sharedInstance] setMinLevel:minLevel];
                            [[Device sharedInstance] setMaxLevel:maxLevel];
                            NSNumber *currentLevel = [[Device sharedInstance] level];
                            if (currentLevel != 0 && (currentLevel < minLevel || currentLevel > maxLevel)) {
                                NSLog(@"[UIC] Account is outside min/max level. Current: %@ Min/Max: %@/%@. Logging out!", currentLevel, minLevel, maxLevel);
                                //self.lock.lock();
                                CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                                [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                                [self logout];
                                //self.lock.unlock();
                            }
                        }
                    }
                    
                    _failedGetJobCount = 0;
                    NSDictionary *data = [result objectForKey:@"data"];
                    if (data != nil) {
                        NSString *action = [data objectForKey:@"action"];
                        _action = action;
                        if ([action isEqualToString:@"scan_pokemon"]) {
                            NSLog(@"[UIC] [STATUS] Pokemon");
                            //[self handlePokemonJob:action withData:data hasWarning:hasWarning];
                            [_jobController handlePokemonJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_raid"]) {
                            NSLog(@"[UIC] [STATUS] Raid");
                            //[self handleRaidJob:action withData:data hasWarning:hasWarning];
                            [_jobController handleRaidJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_quest"]) {
                            NSLog(@"[UIC] [STATUS] Quest/Leveling");
                            //[self handleQuestJob:action withData:data hasWarning:hasWarning];
                            [_jobController handleQuestJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"switch_account"]) {
                            NSLog(@"[UIC] [STATUS] Switching Accounts");
                            //[self handleSwitchAccount:action withData:data hasWarning:hasWarning];
                            [_jobController handleSwitchAccount:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"leveling"]) {
                            NSLog(@"[UIC] [STATUS] Leveling");
                            //[self handleLeveling:action withData:data hasWarning:hasWarning];
                            [_jobController handleLeveling:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_iv"]) {
                            NSLog(@"[UIC] [STATUS] IV");
                            //[self handleIVJob:action withData:data hasWarning:hasWarning];
                            [_jobController handleIVJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"gather_token"]) {
                            NSLog(@"[UIC] [STATUS] Token");
                            //[self handleGatherToken:action withData:data hasWarning:hasWarning];
                            [_jobController handleGatherToken:action withData:data hasWarning:hasWarning];
                        } else {
                            NSLog(@"[UIC] Unknown Action: %@", action);
                        }
                        
                        if (_emptyGmoCount >= [[Settings sharedInstance] maxEmptyGMO]) {
                            NSLog(@"[UIC] Got Empty GMO %@ times in a row. Restarting...", _emptyGmoCount);
                            [self restart];
                        }
                        
                        if (_failedCount >= [[Settings sharedInstance] maxFailedCount]) {
                            NSLog(@"[UIC] Failed %@ times in a row. Restarting...", _failedCount);
                            [self restart];
                        }
                    } else {
                        _failedGetJobCount = 0;
                        NSLog(@"[UIC] No job left (Result: %@)", result);
                        [NSThread sleepForTimeInterval:5];
                    }
                }];
            }
        }
    });
    //dispatch_release(gameStateQueue);
    return 0;
}


#pragma mark Pixel Checks

-(BOOL)clickButton:(NSString *)buttonName
{
    // TODO: clickButton
    return YES;
}

-(BOOL)findButton:(NSString *)buttonName
{
    // TODO: findButton
    return YES;
}

-(NSString *)getMenuButton
{
    // TODO: getMenuButton
    return @"";
}

-(BOOL)eggDeploy
{
    // TODO: EggDeploy
    return false;
}

-(BOOL)getToMainScreen
{
    // TODO: getToMainScreen
    return false;
}


#pragma mark Job Handlers

/*
-(void)handlePokemonJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    if (hasWarning && [[Settings sharedInstance] enableAccountManager]) {
        NSLog(@"[UIC] Account has a warning and tried to scan for Pokemon. Logging out!");
        //self.lock.lock();
        _currentLocation = _startupLocation;
        [self logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = [data objectForKey:@"lat"];
    NSNumber *lon = [data objectForKey:@"lon"];
    NSLog(@"[UIC] Scanning for Pokemon at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    _waitRequiresPokemon = true;
    _pokemonEncounterId = nil;
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    _currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    _waitForData = true;
    //self.lock.unlock();
    NSLog(@"[UIC] Scanning prepared");
    
    BOOL locked = true;
    while (locked) {
        [NSThread sleepForTimeInterval:1];
        //self.lock.lock();
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince >= 30) {
            locked = false;
            _waitForData = false;
            _failedCount = [Utils incrementInt:_failedCount];
            NSLog(@"[UIC] Pokemon loading timed out.");
            NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
            failedData[@"uuid"] = [[Device sharedInstance] uuid];
            failedData[@"username"] = [[Device sharedInstance] username];
            failedData[@"action"] = _action;// TODO: @"scan_pokemon",
            failedData[@"lat"] = lat;
            failedData[@"lon"] = lon;
            failedData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:failedData blocking:true completion:^(NSDictionary *result) {}];
        }
    }
}

-(void)handleRaidJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:_firstWarningDate];
    NSNumber *maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
    if (hasWarning &&
        _firstWarningDate != nil &&
        timeSince >= [maxWarningTimeRaid intValue] &&
        [[Settings sharedInstance] enableAccountManager]) {
        NSLog(@"[UIC] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
        //self.lock.lock();
        _currentLocation = _startupLocation;
        [self logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = [data objectForKey:@"lat"] ?: 0;
    NSNumber *lon = [data objectForKey:@"lon"] ?: 0;
    NSLog(@"[UIC] Scanning for Raid at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    _currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    _waitRequiresPokemon = false;
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    _waitForData = true;
    //self.lock.unlock();
    NSLog(@"[UIC] Scanning prepared.");
    
    BOOL locked = true;
    NSNumber *raidMaxTime = [[Settings sharedInstance] raidMaxTime];
    while (locked) {
        //self.lock.lock();
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince >= [raidMaxTime intValue]) {
            locked = false;
            _waitForData = false;
            _failedCount = [Utils incrementInt:_failedCount];
            NSLog(@"[UIC] Raids loading timed out.");
            NSMutableDictionary *raidData = [[NSMutableDictionary alloc] init];
            raidData[@"uuid"] = [[Device sharedInstance] uuid];
            raidData[@"action"] = @"scan_raid";
            raidData[@"lat"] = lat;
            raidData[@"lon"] = lon;
            raidData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:raidData blocking:true completion:^(NSDictionary *result) {}];
        } else {
            locked = _waitForData;
            if (!locked) {
                _failedCount = 0;
                NSLog(@"[UIC] Raids loaded after %f", timeIntervalSince);
            }
        }
        //self.lock.unlock();
    }
}

-(void)handleQuestJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    _delayQuest = true;
    NSNumber *lat = [data objectForKey:@"lat"];
    NSNumber *lon = [data objectForKey:@"lon"];
    NSNumber *delay = [data objectForKey:@"delay"];
    NSLog(@"[UIC] Scanning for Quest at %@ %@ in %@ seconds", lat, lon, delay);
    
    if (hasWarning && _firstWarningDate != nil && [NSDate date]) {
        NSLog(@"[UIC] Account has a warning and is over maxWarningTimeRaid. Logging out!");
        //self.lock.lock();
        _currentLocation = _startupLocation;
        //self.lock.unlock();
        [self logout];
    }
    
    if ([[Settings sharedInstance] deployEggs] &&
        _eggStart < [NSDate date] &&
        [[[Device sharedInstance] level] intValue] >= 9 &&
        [[[Device sharedInstance] level] intValue] < 30) {
        NSNumber *i = @(arc4random_uniform(60));
        [NSThread sleepForTimeInterval:2];
        if ([self getToMainScreen]) {
            NSLog(@"[UIC] Deploying an egg");
            if ([self eggDeploy]) {
                // If an egg was found, set the timer to 31 minutes.
                _eggStart = [[NSDate date] initWithTimeInterval:(1860 + [i intValue]) sinceDate:[NSDate date]];
            } else {
                // If no egg was used, set the timer to 16 minutes so it rechecks.
                // Useful if you get more eggs from leveling up.
                _eggStart = [[NSDate date] initWithTimeInterval:(960 + [i intValue]) sinceDate:[NSDate date]];
            }
            NSLog(@"[UIC] Egg timer set to %@ UTC for a recheck.", _eggStart);
        } else {
            _eggStart = [[NSDate date] initWithTimeInterval:(960 + [i intValue]) sinceDate:[NSDate date]];
        }
        NSLog(@"[UIC] Egg timer set to %@ UTC for a recheck.", _eggStart);
    }
    
    if (delay >= [[Settings sharedInstance] minDelayLogout] &&
                 [[Settings sharedInstance] enableAccountManager]) {
        NSLog(@"[UIC] Switching account. Delay too large.");
        NSMutableDictionary *questData = [[NSMutableDictionary alloc] init];
        questData[@"uuid"] = [[Device sharedInstance] uuid];
        questData[@"action"] = _action;
        questData[@"lat"] = lat;
        questData[@"lon"] = lon;
        questData[@"type"] = @"job_failed";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:questData blocking:true completion:^(NSDictionary *result) {}];
        //self.lock.lock();
        _currentLocation = _startupLocation;
        //self.lock.unlock();
        [self logout];
    }
    
    _newCreated = false;
    
    //self.lock.lock();
    _currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    _waitRequiresPokemon = false;
    _pokemonEncounterId = nil;
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    _waitForData = true;
    //self.lock.unlock();
    NSLog(@"[UIC] Scanning prepared");
    
    NSDate *start = [NSDate date];
    BOOL success = false;
    BOOL locked = true;
    BOOL found = false;
    while (locked) {
        usleep(100000);
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince <= 5) {
            continue;
        }
        if (!found && (timeIntervalSince <= [delay doubleValue])) {
            NSNumber *left = @([delay doubleValue] - timeIntervalSince);
            //NSNumber *delayDouble = [NSNumber numberWithDouble:[delay doubleValue]];
            //NSDate *end = [[NSDate date] initWithTimeIntervalSince1970:[delayDouble doubleValue]];
            NSLog(@"[UIC] Delaying by %@ seconds.", left);

            while (!found && (timeIntervalSince <= [delay doubleValue])) {
                //self.lock.lock();
                locked = _gotQuestEarly;
                //self.lock.unlock();
                if (locked) {
                    usleep(100000);
                } else {
                    found = true;
                }
            }
            continue;
        }
        //self.lock.lock();
        NSNumber *raidMaxTime = [[Settings sharedInstance] raidMaxTime];
        NSNumber *totalDelay = @([raidMaxTime doubleValue] + [delay doubleValue]);
        if (!found && timeIntervalSince >= [totalDelay doubleValue]) {
            locked = false;
            _waitForData = false;
            _failedCount = [Utils incrementInt:_failedCount];
            NSLog(@"[UIC] Pokestop loading timed out.");
            // TODO: Pass 'action' to method, don't use global _action incase of race condition.
            NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
            failedData[@"uuid"] = [[Device sharedInstance] uuid];
            failedData[@"action"] = _action;
            failedData[@"lat"] = lat;
            failedData[@"lon"] = lon;
            failedData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:failedData blocking:true completion:^(NSDictionary *result) {}];
        } else {
            locked = _waitForData;
            if (!locked) {
                _delayQuest = true;
                success = true;
                _failedCount = 0;
                NSLog(@"[UIC] Pokestop loaded after %f", timeIntervalSince);
            }
        }
        //self.lock.unlock();
    }

    if ([_action isEqualToString:@"scan_quest"]) {
        //self.lock.lock();
        if (_gotQuest) {
            _noQuestCount = 0;
        } else {
            _noQuestCount = [Utils incrementInt:_noQuestCount];
        }
        _gotQuest = false;
        
        if (_noQuestCount >= [[Settings sharedInstance] maxNoQuestCount]) {
            //self.lock.unlock();
            NSLog(@"[UIC] Stuck somewhere. Restarting...");
            [self logout];
        }
        
        //self.lock.unlock();
        if (success) {
            NSNumber *attempts = 0;
            while ([attempts intValue] < 5) {
                attempts = [Utils incrementInt:attempts];
                //self.lock.lock();
                NSLog(@"[UIC] Got quest data: %@", _gotQuest ? @"Yes" : @"No");
                if (!_gotQuest) {
                    NSLog(@"[UIC] UltraQuests pokestop re-attempt: %@", attempts);
                    //self.lock.unlock();
                    [NSThread sleepForTimeInterval:2];
                } else {
                    //self.lock.unlock();
                    //break;
                }
            }
        }
    }
}

-(void)handleLeveling:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    // TODO: Handle Mizu leveling jobs
    _delayQuest = false;
    //degreePerMeter = 83267.0991559005
    NSNumber *lat = [data objectForKey:@"lat"] ?: 0;
    NSNumber *lon = [data objectForKey:@"lon"] ?: 0;
    //NSLog(@"[UIC] Scanning for IV at %@ %@", lat, lon);
    NSNumber *delay = [data objectForKey:@"delay"] ?: @0.0;
    NSString *fortType = [data objectForKey:@"fort_type"] ?: @"P";
    _targetFortId = [data objectForKey:@"fort_id"] ?: @"";
    NSLog(@"[UIC] [RES1] Location: %@ %@ Delay: %@ FortType: %@ FortId: %@", lat, lon, delay, fortType, _targetFortId);
    
    if (!_isQuestInit) {
        _isQuestInit = true;
        delay = @30.0;
    } else {
        CLLocation *newLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        CLLocation *lastLocation = _lastQuestLocation;
        NSNumber *questDistance = [NSNumber numberWithDouble:[newLocation distanceFromLocation:lastLocation]];
        
        // Check if previous spin had quest data
        //self.lock.lock();
        if (_gotItems) {
            _noItemsCount = 0;
        } else {
            _noItemsCount = [Utils incrementInt:_noItemsCount];
        }
        _gotItems = false;
        //self.lock.unlock();
        
        if ([_noItemsCount intValue] >= 200) {
            _isQuestInit = false;
            _noItemsCount = 0;
            NSLog(@"[UIC] Stuck somewhere. Restarting accounts...");
            [self restart];
            [[Device sharedInstance] setShouldExit:true];
            return;
        }
        
        _skipSpin = false;
        NSLog(@"[UIC] Quest Distance: %@", questDistance);
        if ([questDistance intValue] <= 5.0) {
            delay = @0.0;
            _skipSpin = true;
            NSLog(@"[UIC] Quest Distance: %@m < 30.0m Already spun this pokestop. Go to next pokestop.", questDistance);
            _gotItems = true;
        } else if ([questDistance intValue] <= 100.0) {
            delay = @3.0;
        } else if ([questDistance intValue] <= 1000.0) {
            delay = @(([questDistance intValue] / 1000.0) * 60.0);
        } else if ([questDistance intValue] <= 2000.0) {
            delay = @(([questDistance intValue] / 2000.0) * 60.0);
        } else if ([questDistance intValue] <= 4000.0) {
            delay = @(([questDistance intValue] / 4000.0) * 60.0);
        } else if ([questDistance intValue] <= 5000.0) {
            delay = @(([questDistance intValue] / 5000.0) * 60.0);
        } else if ([questDistance intValue] <= 8000.0) {
            delay = @(([questDistance intValue] / 8000.0) * 60.0);
        } else {
            delay = @7200.0;
        }
    }
    
    if (!_skipSpin) {
        NSLog(@"[UIC] Spinning fort at %@ %@ in %@ seconds", lat, lon, delay);
        _lastQuestLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:_firstWarningDate];
        NSNumber *maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
        if (hasWarning &&
            _firstWarningDate != nil &&
            timeSince >= [maxWarningTimeRaid intValue] &&
            [[Settings sharedInstance] enableAccountManager]) {
            NSLog(@"[UIC] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
            //self.lock.lock();
            _currentLocation = _startupLocation;
            [[Device sharedInstance] setUsername:nil];
            [[Device sharedInstance] setIsLoggedIn:false];
            _isQuestInit = false;
            //self.lock.unlock();
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self logout];
        }
        
        _newCreated = false;
        //self.lock.lock();
        _currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        _waitRequiresPokemon = false;
        _pokemonEncounterId = nil;
        //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance] ?: @250.0;
        _waitForData = false;
        //self.lock.unlock();
        NSLog(@"[UIC] Scanning prepared");
        
        NSDate *start = [NSDate date];
        NSNumber *delayTemp = delay;
        bool success = false;
        bool locked = true;
        while (locked) {
            usleep(100000);
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
            if (timeIntervalSince >= [delayTemp intValue]) {
                NSNumber *left = @([delayTemp intValue] - timeIntervalSince);
                NSLog(@"[UIC] Delaying by %@", left);
                // TODO: usleep(UInt32(min(10.0, left) * 100000.0));
                continue;
            }
            //self.lock.lock();
            NSNumber *raidMaxTime = [[Settings sharedInstance] raidMaxTime];
            if (timeIntervalSince >= ([raidMaxTime intValue] + [delayTemp intValue])) {
                locked = false;
                _waitForData = false;
                _failedCount = [Utils incrementInt:_failedCount];
                NSLog(@"[UIC] Pokestop loading timed out...");
                NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
                failedData[@"uuid"] = [[Device sharedInstance] uuid];
                failedData[@"type"] = @"job_failed";
                failedData[@"lat"] = lat;
                failedData[@"lon"] = lon;
                failedData[@"action"] = action;
                [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                              dict:failedData
                          blocking:true
                        completion:^(NSDictionary *result) {}
                ];
            } else {
                locked = _waitForData = true;
                if (!locked) {
                    success = true;
                    _delayQuest = true;
                    _failedCount = 0;
                    NSLog(@"[UIC] Pokestop loaded after %f", [[NSDate date] timeIntervalSinceDate:start]);
                    [NSThread sleepForTimeInterval:1];
                }
            }
            //self.lock.unlock();
        }
        
        if (success) {
            NSLog(@"[UIC] Spinning Pokestop");
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:_lastDeployTime];
            if (([_luckyEggsNum intValue] >= 1 && timeIntervalSince >= 2000) ||
                ([_spins intValue] >= 400 && [[[Device sharedInstance] level] intValue] >= 20)) {
                [self getToMainScreen];
                NSLog(@"[UIC] Clearing Items for UQ");
                if ([self eggDeploy]) {
                    _lastDeployTime = [NSDate date];
                    _luckyEggsNum = [Utils decrementInt:_luckyEggsNum];
                } else {
                    _luckyEggsNum = @0;
                }
                _spins = @0;
                _ultraQuestSpin = true;
                [NSThread sleepForTimeInterval:1];
                NSNumber *attempts = @0;
                NSNumber *sleepUsleep = @200000; // 200ms
                while ([[NSDate date] timeIntervalSinceDate:start] < 15.0 + [delay intValue]) {
                    //self.lock.lock();
                    if (!_gotItems) {
                        //self.lock.unlock();
                        if ([attempts intValue] % 5 == 0) {
                            NSLog(@"[UIC] Waiting to spin...");
                        }
                        usleep([sleepUsleep intValue]);
                    } else {
                        //self.lock.unlock();
                        NSLog(@"[UIC] Successfully spun Pokestop");
                        _ultraQuestSpin = false;
                        //_spins = _spins + 1;
                        //sleep(3 * [[Device sharedInstance] delayMultiplier;
                        break;
                    }
                    attempts = [Utils incrementInt:attempts];
                }
                _ultraQuestSpin = false;
                if (!_gotItems) {
                    NSLog(@"[UIC] Failed to spin Pokestop");
                }
            }
        }
        
    } else {
        NSLog(@"[UIC] Sleep 3 seconds before skipping...");
        [NSThread sleepForTimeInterval:3];
    }
}

-(void)handleIVJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:_firstWarningDate];
    NSNumber *maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
    if (hasWarning &&
        _firstWarningDate != nil &&
        timeSince >= [maxWarningTimeRaid intValue] &&
        [[Settings sharedInstance] enableAccountManager]) {
        NSLog(@"[UIC] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
        //self.lock.lock();
        _currentLocation = _startupLocation;
        [self logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = [data objectForKey:@"lat"] ?: 0;
    NSNumber *lon = [data objectForKey:@"lon"] ?: 0;
    NSLog(@"[UIC] Scanning for IV at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    _waitRequiresPokemon = true;
    //_targetMaxDisance = [[Settings sharedInstance] targetMaxDistance];
    _currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    _waitForData = true;
    //_encounterDelay = [[Settings sharedInstance] encounterDelay];
    //self.lock.unlock();
    NSLog(@"[UIC] Scanning prepared");
    
    bool locked = true;
    while (locked) {
        //self.lock.lock();
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        NSNumber *pokemonMaxTime = [[Settings sharedInstance] pokemonMaxTime];
        if (timeIntervalSince >= [pokemonMaxTime intValue]) {
            locked = false;
            _waitForData = false;
            _failedCount = [Utils incrementInt:_failedCount];
            NSLog(@"[UIC] Raids loading timed out.");
            NSMutableDictionary *raidData = [[NSMutableDictionary alloc] init];
            raidData[@"uuid"] = [[Device sharedInstance] uuid];
            raidData[@"action"] = @"scan_raid";
            raidData[@"lat"] = lat;
            raidData[@"lon"] = lon;
            raidData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:raidData blocking:true completion:^(NSDictionary *result) {}];
        } else {
            locked = _waitForData;
            if (!locked) {
                _failedCount = 0;
                NSLog(@"[UIC] Pokemon loaded after %f", timeIntervalSince);
            }
        }
    }
}

-(void)handleSwitchAccount:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    [[Device sharedInstance] setUsername:nil];
    [[Device sharedInstance] setIsLoggedIn:false];
    _isQuestInit = false;
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self logout];
}

-(void)handleGatherToken:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    if (_menuButton) {
        _menuButton = false;
        NSMutableDictionary *tokenData = [[NSMutableDictionary alloc] init];
        tokenData[@"uuid"] = [[Device sharedInstance] uuid];
        tokenData[@"username"] = [[Device sharedInstance] username];
        tokenData[@"ptcToken"] = _ptcToken;
        tokenData[@"type"] = @"ptcToken";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:tokenData blocking:true completion:^(NSDictionary *result) {}];
        NSLog(@"[UIC] [Jarvis] Received ptcToken, swapping account...");
        [self logout];
    }
}
*/


#pragma mark Request Handlers

-(NSString *)handleLocationRequest:(NSMutableDictionary *)params
{
    NSMutableDictionary *responseData = [[NSMutableDictionary alloc] init];
    //self.lock.lock();
    CLLocation *currentLoc = [[DeviceState sharedInstance] currentLocation];
    if (currentLoc != nil) {
        if ([[DeviceState sharedInstance] waitRequiresPokemon]) {
            //self.lock.unlock();
            NSNumber *jitterValue = [[Settings sharedInstance] jitterValue];
            NSNumber *jitterLat;
            NSNumber *jitterLon;
            switch ([_jitterCorner intValue]) {
                case 0:
                    jitterLat = jitterValue;
                    jitterLon = jitterValue;
                    _jitterCorner = @1;
                    break;
                case 1:
                    jitterLat = jitterValue;
                    jitterLon = jitterValue;
                    _jitterCorner = @2;
                    break;
                case 2:
                    jitterLat = jitterValue;
                    jitterLon = jitterValue;
                    _jitterCorner = @3;
                    break;
                default:
                    jitterLat = jitterValue;
                    jitterLon = jitterValue;
                    _jitterCorner = @0;
                    break;
            }

            NSNumber *currentLat = @([[NSNumber numberWithDouble:currentLoc.coordinate.latitude] doubleValue] + [jitterLat doubleValue]);
            NSNumber *currentLon = @([[NSNumber numberWithDouble:currentLoc.coordinate.longitude] doubleValue] + [jitterLon doubleValue]);
            responseData[@"latitude"] = currentLat;
            responseData[@"longitude"] = currentLon;
            responseData[@"lat"] = currentLat;
            responseData[@"lon"] = currentLon;

            //"scan_iv", "scan_pokemon"
            if ([[[Device sharedInstance] level] intValue] >= 30) {
                responseData[@"actions"] = @[@"pokemon"];
            } else {
                responseData[@"actions"] = @[];
            }
        } else {
            // raids, quests
            //self.lock.unlock();
            NSNumber *currentLat = [NSNumber numberWithDouble:currentLoc.coordinate.latitude];
            NSNumber *currentLon = [NSNumber numberWithDouble:currentLoc.coordinate.longitude];
            responseData[@"latitude"] = currentLat;
            responseData[@"longitude"] = currentLon;
            responseData[@"lat"] = currentLat;
            responseData[@"lon"] = currentLon;
            
            bool ultraQuests = [[Settings sharedInstance] ultraQuests];
            if (ultraQuests && [_action isEqualToString:@"scan_quest"] && _delayQuest) {
                // Auto-spinning should only happen when ultraQuests is
                // set and the instance is scan_quest type
                if ([[[Device sharedInstance] level] intValue] >= 30) {
                    responseData[@"actions"] = @[@"pokemon", @"pokestop"];
                } else {
                    responseData[@"actions"] = @[@"pokestop"];
                }
            } else if ([_action isEqualToString:@"leveling"]) {
                responseData[@"actions"] = @[@"pokestop"];
            } else if ([_action isEqualToString:@"scan_raid"]) {
                // Raid instances do not need IV encounters, Use scan_pokemon
                // type if you want to encounter while scanning raids.
                responseData[@"actions"] = @[];
            }
        }
    }

    // response: "Content-Type" = "application/json";
    
    //NSString *response = [NSString stringWithFormat:@"%@\r\n%@", _response_200, responseData];
    NSString *body = [Utils toJsonString:responseData withPrettyPrint:false];
    NSString *response = [Utils buildResponse:body withResponseCode:Success];
    return response;
}

-(NSString *)handleDataRequest:(NSMutableDictionary *)params
{
    CLLocation *currentLocation = [[DeviceState sharedInstance] currentLocation];
    if (currentLocation == nil) {
        return [Utils buildResponse:@"" withResponseCode:BadRequest];
    }
    _lastUpdate = [NSDate date];
    CLLocation *currentLoc = [Utils createCoordinate:currentLocation.coordinate.latitude lon: currentLocation.coordinate.longitude];
    //NSNumber *targetMaxDistance = _targetMaxDistance;
    NSString *pokemonEncounterId = _pokemonEncounterId;
    params[@"lat_target"] = @(currentLoc.coordinate.latitude);
    params[@"lon_target"] = @(currentLoc.coordinate.longitude);
    params[@"target_max_distance"] = [[Settings sharedInstance] targetMaxDistance];
    params[@"username"] = [[Device sharedInstance] username] ?: @"";
    params[@"pokemon_encounter_id"] = pokemonEncounterId ?: @"";
    params[@"uuid"] = [[Device sharedInstance] uuid];
    params[@"ptcToken"] = _ptcToken ?: @"";

    NSString *url = [[Settings sharedInstance] backendRawUrl];
    [Utils postRequest:url dict:params blocking:false completion:^(NSDictionary *result) {
        NSDictionary *data = [result objectForKey:@"data"];
        
        bool inArea = data[@"in_area"] ?: false;
        NSNumber *level = data[@"level"] ?: @0;
        NSNumber *nearby = data[@"nearby"] ?: @0;
        NSNumber *wild = data[@"wild"] ?: @0;
        NSNumber *quests = data[@"quests"] ?: @0;
        NSNumber *encounters = data[@"encounters"] ?: @0;
        NSNumber *pokemonLat = data[@"pokemon_lat"] ?: @0.0;
        NSNumber *pokemonLon = data[@"pokemon_lon"] ?: @0.0;
        NSString *pokemonEncounterIdResult = data[@"pokemon_encounter_id"];
        NSNumber *targetLat = data[@"target_lat"] ?: @0.0;
        NSNumber *targetLon = data[@"target_lon"] ?: @0.0;
        bool onlyEmptyGmos = data[@"only_empty_gmos"] ?: @(true);
        bool onlyInvalidGmos = data[@"only_invalid_gmos"] ?: @(false);
        bool containsGmo = data[@"contains_gmos"] ?: @(true);
        
        NSNumber *pokemonFoundCount = [NSNumber numberWithFloat:([wild intValue] + [nearby intValue])];
        [[Device sharedInstance] setLevel:level];
        NSString *toPrint;
        
        //self.lock.lock();
        NSNumber *diffLat = @([[NSNumber numberWithDouble:currentLoc.coordinate.latitude] doubleValue] - [targetLat doubleValue]);
        NSNumber *diffLon = @([[NSNumber numberWithDouble:currentLoc.coordinate.longitude] doubleValue] - [targetLon doubleValue]);
        
        // TODO: MIZU tut stuff
        NSString *spinFortId = data[@"spin_fort_id"] ?: @"";
        NSNumber *spinFortLat = data[@"spin_fort_lat"] ?: @0.0;
        NSNumber *spinFortLon = data[@"spin_fort_lon"] ?: @0.0;
        if ([level intValue] > 0) {
            if ([[Device sharedInstance] level] != level) {
                NSArray *luckyEggLevels = @[ @9, @10, @15, @20, @25];
                if ([luckyEggLevels containsObject:level]) {
                    [Utils incrementInt:_luckyEggsNum];
                }
            }
            [[Device sharedInstance] setLevel:level];
            NSLog(@"[UIC] Level from RDM: %@ quests: %@", [[Device sharedInstance] level], quests);
        }
        
        NSLog(@"[UIC] [RES1] inArea: %s level: %@ nearby: %@ wild: %@ quests: %@ encounters: %@ plat: %@ plon: %@ encounterResponseId: %@ tarlat: %@ tarlon: %@ emptyGMO: %s invalidGMO: %s containsGMO: %s", (inArea ? "Yes" : "No"), level, nearby, wild, quests, encounters, pokemonLat, pokemonLon, pokemonEncounterIdResult, targetLat, targetLon, (onlyEmptyGmos ? "Yes" : "No"), (onlyInvalidGmos ? "Yes" : "No"), (containsGmo ? "Yes" : "No"));
        NSLog(@"[UIC] [DEBUG] SpinFortLat: %@ SpinFortLon: %@", spinFortLat, spinFortLon);
        
        NSNumber *itemDistance = @10000.0;
        if (([spinFortId isEqualToString:@""] || spinFortId == nil) && [spinFortLat doubleValue] != 0.0) {
            CLLocation *fortLocation = [Utils createCoordinate:[spinFortLat doubleValue] lon:[spinFortLon doubleValue]];
            itemDistance = [NSNumber numberWithDouble:[fortLocation distanceFromLocation:currentLoc]];
            NSLog(@"[UIC] [DEBUG] ItemDistance: %@", itemDistance);
        }
        
        if (onlyInvalidGmos) {
            [[DeviceState sharedInstance] setWaitForData:false];
            toPrint = @"[UIC] Got GMO but it was malformed. Skipping.";
        } else if (containsGmo) {
            if (inArea && [diffLat doubleValue] < 0.0001 && [diffLon doubleValue] < 0.0001) {
                _emptyGmoCount = 0;
                if (_pokemonEncounterId != nil) {
                    if ([pokemonFoundCount intValue] > 0) {
                        if (pokemonLat != 0 && pokemonLon != 0 && _pokemonEncounterId == pokemonEncounterIdResult) {
                            [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
                            CLLocation *oldLocation = [[DeviceState sharedInstance] currentLocation];
                            [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[pokemonLat doubleValue] lon:[pokemonLon doubleValue]]];
                            CLLocation *newLocation = [[DeviceState sharedInstance] currentLocation];
                            _encounterDistance = [NSNumber numberWithDouble:[newLocation distanceFromLocation:oldLocation]];
                            _pokemonEncounterId = nil;
                            [[DeviceState sharedInstance] setWaitForData:false];
                            toPrint = @"[UIC] Got Data and found Pokemon";
                        } else {
                            toPrint = @"[UIC] Got Data but did not find Pokemon";
                        }
                    } else {
                        toPrint = @"[UIC] Got Data without Pokemon";
                    }
                } else if ([[DeviceState sharedInstance] waitRequiresPokemon]) {
                    if ([pokemonFoundCount intValue] > 0) {
                        toPrint = @"[UIC] Got Data with Pokemon";
                        [[DeviceState sharedInstance] setWaitForData:false];
                    } else {
                        toPrint = @"[UIC] Got Data without Pokemon";
                    }
                } else {
                    toPrint = @"[UIC] Got Data";
                    [[DeviceState sharedInstance] setWaitForData:false];
                }
            } else if (onlyEmptyGmos && !_startup) {
                _emptyGmoCount = [Utils incrementInt:_emptyGmoCount];
                toPrint = @"[UIC] Got Empty Data";
            } else {
                _emptyGmoCount = 0;
                toPrint = @"[UIC] Got Data outside Target-Area";
            }
        } else {
            toPrint = @"[UIC] Got Data without GMO";
        }

        if (![[DeviceState sharedInstance] gotQuest] && quests != 0) {
            [[DeviceState sharedInstance] setGotQuest:true];
            _gotQuestEarly = true;
        }
        
        if (![[DeviceState sharedInstance] gotIV] && encounters != 0) {
            [[DeviceState sharedInstance] setGotIV:true];
        }
        
        NSLog(@"[UIC] Handle data response: %@", toPrint);
    }];
    NSString *body = [Utils toJsonString:params withPrettyPrint:false];
    NSString *response = [Utils buildResponse:body withResponseCode:Success];
    return response;
}

@end

/*
@interface XCTestCase (KIFFramework) <KIFTestActorDelegate>

//-(KIFUIViewTestActor)viewTester:(NSString *)file = #__FILE__ withLine:(NSInteger *)line = #__LINE__;
//-(KIFSystemTextActor)system:(NSString *)file = #__FILE__ withLine:(NSInteger *)line = #__LINE__;

@end

@implementation XCodeTest (KIFFramework)

-(KIFUIViewTestActor)viewTest:(NSString *)file = #__FILE__ withLine:(NSInteger *)line = #__LINE__
{
}

-(KIFSystemTextActor)system:(NSString *)file = #__FILE__ withLine:(NSInteger *)line = #__LINE__
{
}

@end
*/
