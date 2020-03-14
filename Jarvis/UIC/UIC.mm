//
//  UIC.cpp
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "UIC.h"
//#import <XCTest/XCTest.h>

// TODO: KIF library
// TODO: StateManager class
// TODO: Pixel checks
// TODO: Pixel offsets in remote config

#pragma mark Global Variables

static BOOL _firststart = true;
static BOOL _startup = true;
//static BOOL _started = false;
//static NSLock *_lock = [[NSLock alloc] init];
static NSNumber *_jitterCorner = @0;
//static NSString *_action;
//static NSNumber *_encounterDistance = @0.0;
//static NSNumber *_encounterDelay = @0.0;

// Button Detection
static BOOL _menuButton = false;
//static BOOL _menuButton2 = false;
static NSString *_neededButton = @"";
//static BOOL _okButton = false;
static BOOL _newPlayerButton = false;
static BOOL _bannedScreen = false;
static BOOL _invalidScreen = false;


@implementation UIC2

//static HttpServer *_httpServer;
static HTTPServer *_httpServer;
static JobController *_jobController;
static RMPaperTrailLogger *_logger;

#pragma mark Constructor/Deconstructor

-(id)init
{
    NSLog(@"[Jarvis] [UIC] init");
    if ((self = [super init]))
    {
        _logger = [RMPaperTrailLogger sharedInstance];
        _logger.host = [[Settings sharedInstance] loggingUrl];
        _logger.port = [[[Settings sharedInstance] loggingPort] intValue];
        _logger.debug = false; // Silences some NSLogging
        _logger.useTcp = [[Settings sharedInstance] loggingTcp]; // TLS is on by default on OS X and ignored on iOS
        _logger.useTLS = [[Settings sharedInstance] loggingTls]; // Use TLS
        [DDLog addLogger:_logger];
    }
    
    return self;
}

-(void)dealloc
{
    [_httpServer release];
    [super dealloc];
}


#pragma mark App Manager

-(void)start
{
    NSLog(@"[Jarvis] [UIC] start");
    NSLog(@"-----------------------------");
    NSLog(@"[Jarvis] [UIC] Device Uuid: %@", [[Device sharedInstance] uuid]);
    NSLog(@"[Jarvis] [UIC] Device Model: %@", [[Device sharedInstance] model]);
    NSLog(@"[Jarvis] [UIC] Device OS: %@", [[Device sharedInstance] osName]);
    NSLog(@"[Jarvis] [UIC] Device OS Version: %@", [[Device sharedInstance] osVersion]);
    //NSLog(@"[Jarvis] [UIC] Device Delay Multiplier: %@", [[Device sharedInstance] multiplier]);
    NSLog(@"-----------------------------");
    
    // Print settings
    [[Settings sharedInstance] config];

    //NSLog(@"Testing RESTART in 3 seconds...");
    //[NSThread sleepForTimeInterval:3];
    //[self restart];
    
    // Initialize job controller
    _jobController = [[JobController alloc] init];

    // Initalize our http server
    _httpServer = [[HTTPServer alloc] init];
    
    // Tell the server to broadcast its presence via Bonjour.
    // This allows browsers such as Safari to automatically discover our service.
    [_httpServer setType:@"_http._tcp."];
    
    // Normally there's no need to run our server on any specific port.
    // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
    // However, for easy testing you may want force a certain port so you can just hit the refresh button.
    [_httpServer setPort:[[[Settings sharedInstance] port] intValue]];
    
    // We're going to extend the base HTTPConnection class with our MyHTTPConnection class.
    // This allows us to do all kinds of customizations.
    [_httpServer setConnectionClass:[HttpClientConnection class]];

    NSError *error = nil;
    if (![_httpServer start:&error]) {
        NSLog(@"[Jarvis] [UIC] Error starting HTTP Server: %@", error);
    }

    [self startHeatbeatLoop];
    
    [self startUicLoop];
}

-(void)startHeatbeatLoop
{
    bool heatbeatRunning = true;
    NSLog(@"[Jarvis] [UIC] Starting heatbeat dispatch queue...");
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    data[@"uuid"] = [[Device sharedInstance] uuid];
    data[@"username"] = [[Device sharedInstance] username];
    data[@"type"] = @"heartbeat";
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:data
              blocking:false
            completion:^(NSDictionary *result) {}
    ];
    dispatch_queue_t heatbeatQueue = dispatch_queue_create("heatbeat_queue", NULL);
    dispatch_async(heatbeatQueue, ^{
        while (heatbeatRunning) {
            // Check if time since last checking was within 2 minutes, if not reboot device.
            [NSThread sleepForTimeInterval:15];
            NSDate *lastUpdate = [[DeviceState sharedInstance] lastUpdate];
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:lastUpdate];
            if (timeIntervalSince >= 120) {
                NSLog(@"[Jarvis] [UIC] HTTP SERVER DIED. Restarting...");
                [DeviceState restart];
            } else {
                NSLog(@"[Jarvis] [UIC] Last data %f We Good", timeIntervalSince);
            }
        }
        
        // Force stop HTTP listener to prevent binding issues.
        NSLog(@"[Jarvis] [UIC] Force-stopping HTTP server.");
        [_httpServer stop];
    });
    //dispatch_release(heatbeatQueue);
}

-(void)startUicLoop
{
    NSLog(@"[Jarvis] [UIC] startUicLoop");
    NSDate *eggStart = [NSDate dateWithTimeInterval:-1860 sinceDate:[NSDate date]];
    NSLog(@"[Jarvis] [UIC] Setting eggStart...");
    [[DeviceState sharedInstance] setEggStart:eggStart];
    // Init AI
    //initJarvis();

    [self loginStateHandler];
}


#pragma mark State Managers

-(void)loginStateHandler
{
    NSLog(@"[Jarvis] [UIC] loginStateHandler");
    dispatch_queue_t loginStateQueue = dispatch_queue_create("login_state_queue", NULL);
    dispatch_async(loginStateQueue, ^{
        NSNumber *startupCount = @0;
        while (_startup) {
            if (!_firststart) {
                NSLog(@"[Jarvis] [UIC] App still in startup...");
                //[NSThread sleepForTimeInterval:60];
                while (!_menuButton) {
                    _newPlayerButton = [Jarvis__ clickButton:@"NewPlayerButton"];
                    NSLog(@"[Jarvis] Found NewPlayerButton: %s", _newPlayerButton ? "Yes" : "No");
                    if (_newPlayerButton) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TOKEN_USER_DEFAULT_KEY];
                        _newPlayerButton = false;
                        NSLog(@"[Jarvis] [UIC] Started at Login Screen");
                        [NSThread sleepForTimeInterval:1];
                        bool ptcButton = false;
                        NSNumber *ptcTryCount = @0;
                        while (!ptcButton) {
                            ptcButton = [Jarvis__ clickButton:@"TrainerClubButton"];
                            ptcTryCount = [Utils incrementInt:ptcTryCount];
                            if ([ptcTryCount intValue] > 10) {
                                _newPlayerButton = [Jarvis__ clickButton:@"NewPlayerButton"];
                                ptcTryCount = @0;
                            }
                            [NSThread sleepForTimeInterval:1];
                        }
                        
                        bool usernameButton = false;
                        while (!usernameButton) {
                            usernameButton = [Jarvis__ clickButton:@"UsernameButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        // TODO: typeUsername();
                        [NSThread sleepForTimeInterval:1];
                        
                        bool passwordButton = false;
                        while (!passwordButton) {
                            passwordButton = [Jarvis__ clickButton:@"PasswordButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        // TODO: typePassword();
                        [NSThread sleepForTimeInterval:1];
                        
                        // TODO: touchAtPoint(180, 100);
                        [NSThread sleepForTimeInterval:1];
                        
                        bool signinButton = false;
                        while (!signinButton) {
                            signinButton = [Jarvis__ clickButton:@"SignInButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        
                        NSNumber *delayMultiplier = [[Device sharedInstance] multiplier];
                        NSNumber *sleep = @([delayMultiplier intValue] + 15);
                        [NSThread sleepForTimeInterval:[sleep intValue]];
                    }
                    
                    _bannedScreen = [Jarvis__ findButton:@"BannedScreen"];
                    if (_bannedScreen) {
                        _bannedScreen = false;
                        NSLog(@"[Jarvis] [UIC] [Jarvis] Account banned, switching accounts.");
                        NSLog(@"[Jarvis] [UIC] [Jarvis] Username: %@", [[Device sharedInstance] username]);
                        NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
                        data[@"uuid"] = [[Device sharedInstance] uuid];
                        data[@"username"] = [[Device sharedInstance] username];
                        data[@"type"] = @"account_banned";
                        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                                      dict:data
                                  blocking:true
                                completion:^(NSDictionary *result) {}
                        ];
                        [DeviceState logout];
                    }
                    
                    _invalidScreen = [Jarvis__ findButton:@"WrongUser"];
                    if (_invalidScreen) {
                        _invalidScreen = false;
                        NSLog(@"[Jarvis] [UIC] [Jarvis] Wrong username, switching accounts.");
                        NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
                        data[@"uuid"] = [[Device sharedInstance] uuid];
                        data[@"username"] = [[Device sharedInstance] username];
                        data[@"type"] = @"account_banned"; // TODO: Uhhh should be account_invalid_credentials no?
                        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                                      dict:data
                                  blocking:true
                                completion:^(NSDictionary *result) {}
                        ];
                        [DeviceState logout];
                    }
                    
                    _neededButton = [Jarvis__ getMenuButton];
                    if ([_neededButton isEqualToString:@"DifferentAccountButton"]) {
                        NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
                        data[@"uuid"] = [[Device sharedInstance] uuid];
                        data[@"username"] = [[Device sharedInstance] username];
                        data[@"type"] = @"account_invalid_credentials";
                        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                                      dict:data
                                  blocking:true
                                completion:^(NSDictionary *result) {}
                        ];
                        [DeviceState logout];
                    }
                    
                    if ([_neededButton isEqualToString:@"MenuButton"]) {
                        _menuButton = true;
                    }
                    
                    [NSThread sleepForTimeInterval:5];
                    if ([startupCount intValue] > 10) {
                        NSLog(@"[Jarvis] [UIC] [Jarvis] Stuck somewhere logging out and restarting...");
                        [DeviceState logout];
                    }
                    startupCount = [Utils incrementInt:startupCount];
                }
                
                [NSThread sleepForTimeInterval:1];
                NSMutableDictionary *tokenData = [[NSMutableDictionary alloc] init];
                tokenData[@"uuid"] = [[Device sharedInstance] uuid];
                tokenData[@"username"] = [[Device sharedInstance] username];
                tokenData[@"ptcToken"] = [[Device sharedInstance] ptcToken];
                tokenData[@"type"] = @"ptcToken";
                [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                              dict:tokenData
                          blocking:true
                        completion:^(NSDictionary *result) {}
                ];
                NSLog(@"[Jarvis] [UIC] [Jarvis] App in Main Screen stopping detection.");
                [Jarvis__ clickButton:@"TrackerButton"];
                _startup = false;
            } else {
                NSLog(@"[Jarvis] [UIC] First startup, waiting...");
                [NSThread sleepForTimeInterval:10];
                _firststart = false;
            }
            [NSThread sleepForTimeInterval:3];
        }
    });
    //dispatch_release(loginStateQueue);
}

-(void)gameStateHandler
{
    // TODO: qos: background dispatch
    dispatch_queue_t gameStateQueue = dispatch_queue_create("game_state_queue", NULL);
    dispatch_async(gameStateQueue, ^{
        bool hasWarning = false;
        [[DeviceState sharedInstance] setFailedGetJobCount:0];
        [[DeviceState sharedInstance] setFailedCount:0];
        [[DeviceState sharedInstance] setEmptyGmoCount:0];
        //_noEncounterCount = 0;
        [[DeviceState sharedInstance] setNoQuestCount:0];
        
        NSMutableDictionary *initData = [[NSMutableDictionary alloc] init];
        initData[@"uuid"] = [[Device sharedInstance] uuid];
        initData[@"username"] = [[Device sharedInstance] username];
        initData[@"type"] = @"init";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:initData blocking:true completion:^(NSDictionary *result) {
            if (result == nil) {
                NSLog(@"[Jarvis] [UIC] Failed to connect to backend!");
                [NSThread sleepForTimeInterval:5];
                [DeviceState restart];
            } else if (![(result[@"status"] ?: @"fail") isEqualToString:@"ok"]) {
                NSString *error = result[@"error"] ?: @"? (No error sent)";
                NSLog(@"[Jarvis] [UIC] Backend returned error: %@", error);
                [[Device sharedInstance] setShouldExit:true];
            }
            
            NSDictionary *data = result[@"data"];
            if (data == nil) {
                NSLog(@"[Jarvis] [UIC] Backend did not include data in response.");
                [[Device sharedInstance] setShouldExit:true];
            }
            
            if (!(data[@"assigned"] ?: false)) {
                NSLog(@"[Jarvis] [UIC] Device is not assigned to an instance!");
                [[Device sharedInstance] setShouldExit:true];
            }
            
            NSNumber *firstWarningTimestamp = data[@"first_warning_timestamp"];
            if (firstWarningTimestamp != nil) {
                NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
            }
            
            NSLog(@"[Jarvis] [UIC] Connected to backend successfully!");
            [[Device sharedInstance] setShouldExit:false];
        }];
        
        if ([[Device sharedInstance] shouldExit]) {
            [[Device sharedInstance] setShouldExit:false];
            [NSThread sleepForTimeInterval:5];
            [DeviceState restart];
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
                NSDictionary *data = result[@"data"];
                if (data != nil) {
                    NSString *username = data[@"username"];
                    NSString *password = data[@"password"];
                    NSNumber *level = data[@"level"];
                    NSDictionary *job = data[@"job"];
                    NSNumber *startLat = job[@"lat"];
                    NSNumber *startLon = job[@"lon"];
                    NSNumber *lastLat = data[@"last_encounter_lat"];
                    NSNumber *lastLon = data[@"last_encounter_lon"];
                    
                    if (username != nil) {
                        NSLog(@"[Jarvis] [UIC] Got account %@ level %@ from backend.", username, level);
                    } else {
                        NSLog(@"[Jarvis] [UIC] Failed to get account and not logged in.");
                        [[Device sharedInstance] setShouldExit:true];
                    }
                    [[Device sharedInstance] setUsername:username];
                    [[Device sharedInstance] setPassword:password];
                    [[Device sharedInstance] setLevel:level];
                    [[Device sharedInstance] setIsLoggedIn:false];
                    CLLocation *startupLocation;
                    if ([startLat doubleValue] != 0.0 && [startLon doubleValue] != 0.0) {
                        startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                    } else if ([lastLat doubleValue] != 0.0 && [lastLon doubleValue] != 0.0) {
                        startupLocation = [Utils createCoordinate:[lastLat doubleValue] lon:[lastLon doubleValue]];
                    } else {
                        startupLocation = [Utils createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                    }
                    [[DeviceState sharedInstance] setStartupLocation:startupLocation];
                    [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                    NSLog(@"[Jarvis] [UIC] StartupLocation: %@", startupLocation);
                    NSNumber *firstWarningTimestamp = data[@"first_warning_timestamp"];
                    if (firstWarningTimestamp != nil) {
                        NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                        [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
                    }
                } else {
                    NSLog(@"[Jarvis] [UIC] Failed to get account and not logged in.");
                    [[Device sharedInstance] setMinLevel:@1]; // Never set to 0 until we can complete tutorials.
                    [[Device sharedInstance] setMaxLevel:@29];
                    [NSThread sleepForTimeInterval:1];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
                    [NSThread sleepForTimeInterval:5];
                    [[Device sharedInstance] setIsLoggedIn:false];
                    [DeviceState restart];
                }
            }];
        }
        
        while (![[Device sharedInstance] shouldExit]) {
            while (!_startup) {
                if ([[DeviceState sharedInstance] needsLogout]) {
                    //self.lock.lock();
                    CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                    [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                    //self.lock.unlock();
                    [DeviceState logout];
                }
                NSMutableDictionary *getJobData = [[NSMutableDictionary alloc] init];
                getJobData[@"uuid"] = [[Device sharedInstance] uuid];
                getJobData[@"username"] = [[Device sharedInstance] username];
                getJobData[@"type"] = @"get_job";
                [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:getJobData blocking:true completion:^(NSDictionary *result) {
                    if (result == nil) {
                        NSNumber *failedGetJobCount = [[DeviceState sharedInstance] failedGetJobCount];
                        if ([failedGetJobCount intValue] == 10) {
                            NSLog(@"[Jarvis] [UIC] Failed to get job 10 times in a row. Exiting...");
                            [[Device sharedInstance] setShouldExit:true];
                        } else {
                            NSLog(@"[Jarvis] [UIC] Failed to get a job.");
                        }
                    } else if ([[Settings sharedInstance] enableAccountManager]) {
                        NSDictionary *data = result[@"data"];
                        if (data != nil) {
                            NSNumber *minLevel = data[@"min_level"];
                            NSNumber *maxLevel = data[@"max_level"];
                            [[Device sharedInstance] setMinLevel:minLevel];
                            [[Device sharedInstance] setMaxLevel:maxLevel];
                            NSNumber *currentLevel = [[Device sharedInstance] level];
                            if (currentLevel != 0 && (currentLevel < minLevel || currentLevel > maxLevel)) {
                                NSLog(@"[Jarvis] [UIC] Account is outside min/max level. Current: %@ Min/Max: %@/%@. Logging out!", currentLevel, minLevel, maxLevel);
                                //self.lock.lock();
                                CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                                [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                                [DeviceState logout];
                                //self.lock.unlock();
                            }
                        }
                    }
                    
                    [[DeviceState sharedInstance] setFailedGetJobCount:0];
                    NSDictionary *data = result[@"data"];
                    if (data != nil) {
                        NSString *action = data[@"action"];
                        [[DeviceState sharedInstance] setLastAction:action];
                        if ([action isEqualToString:@"scan_pokemon"]) {
                            NSLog(@"[Jarvis] [UIC] [STATUS] Pokemon");
                            [_jobController handlePokemonJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_raid"]) {
                            NSLog(@"[Jarvis] [UIC] [STATUS] Raid");
                            [_jobController handleRaidJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_quest"]) {
                            NSLog(@"[Jarvis] [UIC] [STATUS] Quest/Leveling");
                            [_jobController handleQuestJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"switch_account"]) {
                            NSLog(@"[Jarvis] [UIC] [STATUS] Switching Accounts");
                            [_jobController handleSwitchAccount:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"leveling"]) {
                            NSLog(@"[Jarvis] [UIC] [STATUS] Leveling");
                            [_jobController handleLeveling:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_iv"]) {
                            NSLog(@"[Jarvis] [UIC] [STATUS] IV");
                            [_jobController handleIVJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"gather_token"]) {
                            NSLog(@"[Jarvis] [UIC] [STATUS] Token");
                            [_jobController handleGatherToken:action withData:data hasWarning:hasWarning];
                        } else {
                            NSLog(@"[Jarvis] [UIC] Unknown Action: %@", action);
                        }
                        
                        NSNumber *emptyGmoCount = [[DeviceState sharedInstance] emptyGmoCount];
                        NSNumber *maxEmptyGMO = [[Settings sharedInstance] maxEmptyGMO];
                        if (emptyGmoCount >= maxEmptyGMO) {
                            NSLog(@"[Jarvis] [UIC] Got Empty GMO %@ times in a row. Restarting...", emptyGmoCount);
                            [DeviceState restart];
                        }
                        
                        NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
                        if (failedCount >= [[Settings sharedInstance] maxFailedCount]) {
                            NSLog(@"[Jarvis] [UIC] Failed %@ times in a row. Restarting...", failedCount);
                            [DeviceState restart];
                        }
                    } else {
                        [[DeviceState sharedInstance] setFailedGetJobCount:0];
                        NSLog(@"[Jarvis] [UIC] No job left (Result: %@)", result);
                        [NSThread sleepForTimeInterval:5];
                    }
                }];
            }
        }
    });
    //dispatch_release(gameStateQueue);
}


#pragma mark Request Handlers

+(NSString *)handleLocationRequest:(NSDictionary *)params
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
            bool delayQuest = [[DeviceState sharedInstance] delayQuest];
            NSString *action = [[DeviceState sharedInstance] lastAction];
            if (ultraQuests && [action isEqualToString:@"scan_quest"] && delayQuest) {
                // Auto-spinning should only happen when ultraQuests is
                // set and the instance is scan_quest type
                if ([[[Device sharedInstance] level] intValue] >= 30) {
                    responseData[@"actions"] = @[@"pokemon", @"pokestop"];
                } else {
                    responseData[@"actions"] = @[@"pokestop"];
                }
            } else if ([action isEqualToString:@"leveling"]) {
                responseData[@"actions"] = @[@"pokestop"];
            } else if ([action isEqualToString:@"scan_raid"]) {
                // Raid instances do not need IV encounters, Use scan_pokemon
                // type if you want to encounter while scanning raids.
                responseData[@"actions"] = @[];
            }
        }
    }

    NSString *response = [Utils toJsonString:responseData withPrettyPrint:false];
    [responseData release];
    return response;
}

+(NSString *)handleDataRequest:(NSDictionary *)params
{
    CLLocation *currentLocation = [[DeviceState sharedInstance] currentLocation];
    if (currentLocation == nil) {
        return @"Error"; // TODO: Return json response { status: error }
    }
    [[DeviceState sharedInstance] setLastUpdate:[NSDate date]];
    CLLocation *currentLoc = [Utils createCoordinate:currentLocation.coordinate.latitude lon: currentLocation.coordinate.longitude];
    //NSNumber *targetMaxDistance = _targetMaxDistance;
    NSString *pokemonEncounterId = [[DeviceState sharedInstance] pokemonEncounterId];
    NSMutableDictionary *data = [params copy];
    data[@"lat_target"] = @(currentLoc.coordinate.latitude);
    data[@"lon_target"] = @(currentLoc.coordinate.longitude);
    data[@"target_max_distance"] = [[Settings sharedInstance] targetMaxDistance];
    data[@"username"] = [[Device sharedInstance] username] ?: @"";
    data[@"pokemon_encounter_id"] = pokemonEncounterId ?: @"";
    data[@"uuid"] = [[Device sharedInstance] uuid];
    data[@"ptcToken"] = [[Device sharedInstance] ptcToken];

    NSString *url = [[Settings sharedInstance] backendRawUrl];
    [Utils postRequest:url dict:data blocking:false completion:^(NSDictionary *result) {
        NSDictionary *data = result[@"data"];
        
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
                    NSNumber *luckyEggsCount = [[DeviceState sharedInstance] luckyEggsCount];
                    [[DeviceState sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount]];
                }
            }
            [[Device sharedInstance] setLevel:level];
            NSLog(@"[Jarvis] [UIC] Level from RDM: %@ quests: %@", [[Device sharedInstance] level], quests);
        }
        
        NSLog(@"[Jarvis] [UIC] [RES1] inArea: %s level: %@ nearby: %@ wild: %@ quests: %@ encounters: %@ plat: %@ plon: %@ encounterResponseId: %@ tarlat: %@ tarlon: %@ emptyGMO: %s invalidGMO: %s containsGMO: %s", (inArea ? "Yes" : "No"), level, nearby, wild, quests, encounters, pokemonLat, pokemonLon, pokemonEncounterIdResult, targetLat, targetLon, (onlyEmptyGmos ? "Yes" : "No"), (onlyInvalidGmos ? "Yes" : "No"), (containsGmo ? "Yes" : "No"));
        NSLog(@"[Jarvis] [UIC] [DEBUG] SpinFortLat: %@ SpinFortLon: %@", spinFortLat, spinFortLon);

        //NSNumber *itemDistance = @10000.0;
        if (([spinFortId isEqualToString:@""] || spinFortId == nil) && [spinFortLat doubleValue] != 0.0) {
            CLLocation *fortLocation = [Utils createCoordinate:[spinFortLat doubleValue] lon:[spinFortLon doubleValue]];
            NSNumber *itemDistance = [NSNumber numberWithDouble:[fortLocation distanceFromLocation:currentLoc]];
            NSLog(@"[Jarvis] [UIC] [DEBUG] ItemDistance: %@", itemDistance);
        }
        
        if (onlyInvalidGmos) {
            [[DeviceState sharedInstance] setWaitForData:false];
            toPrint = @"[Jarvis] [UIC] Got GMO but it was malformed. Skipping.";
        } else if (containsGmo) {
            if (inArea && [diffLat doubleValue] < 0.0001 && [diffLon doubleValue] < 0.0001) {
                [[DeviceState sharedInstance] setEmptyGmoCount:0];
                NSString *pokemonEncounterId = [[DeviceState sharedInstance] pokemonEncounterId];
                if (pokemonEncounterId != nil) {
                    if ([pokemonFoundCount intValue] > 0) {
                        if (pokemonLat != 0 && pokemonLon != 0 && pokemonEncounterId == pokemonEncounterIdResult) {
                            [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
                            //CLLocation *oldLocation = [[DeviceState sharedInstance] currentLocation];
                            [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[pokemonLat doubleValue] lon:[pokemonLon doubleValue]]];
                            //CLLocation *newLocation = [[DeviceState sharedInstance] currentLocation];
                            //_encounterDistance = [NSNumber numberWithDouble:[newLocation distanceFromLocation:oldLocation]];
                            [[DeviceState sharedInstance] setPokemonEncounterId:nil];
                            [[DeviceState sharedInstance] setWaitForData:false];
                            toPrint = @"[Jarvis] [UIC] Got Data and found Pokemon";
                        } else {
                            toPrint = @"[Jarvis] [UIC] Got Data but did not find Pokemon";
                        }
                    } else {
                        toPrint = @"[Jarvis] [UIC] Got Data without Pokemon";
                    }
                } else if ([[DeviceState sharedInstance] waitRequiresPokemon]) {
                    if ([pokemonFoundCount intValue] > 0) {
                        toPrint = @"[Jarvis] [UIC] Got Data with Pokemon";
                        [[DeviceState sharedInstance] setWaitForData:false];
                    } else {
                        toPrint = @"[Jarvis] [UIC] Got Data without Pokemon";
                    }
                } else {
                    toPrint = @"[Jarvis] [UIC] Got Data";
                    [[DeviceState sharedInstance] setWaitForData:false];
                }
            } else if (onlyEmptyGmos && !_startup) {
                NSNumber *emptyGmoCount = [[DeviceState sharedInstance] emptyGmoCount];
                [[DeviceState sharedInstance] setEmptyGmoCount:emptyGmoCount];
                toPrint = @"[Jarvis] [UIC] Got Empty Data";
            } else {
                [[DeviceState sharedInstance] setEmptyGmoCount:0];
                toPrint = @"[Jarvis] [UIC] Got Data outside Target-Area";
            }
        } else {
            toPrint = @"[Jarvis] [UIC] Got Data without GMO";
        }

        if (![[DeviceState sharedInstance] gotQuest] && quests != 0) {
            [[DeviceState sharedInstance] setGotQuest:true];
            [[DeviceState sharedInstance] setGotQuestEarly:true];
        }
        
        if (![[DeviceState sharedInstance] gotIV] && encounters != 0) {
            [[DeviceState sharedInstance] setGotIV:true];
        }
        
        NSLog(@"[Jarvis] [UIC] Handle data response: %@", toPrint);
    }];
    NSString *response = [Utils toJsonString:data withPrettyPrint:false];
    return response;
}

+(NSString *)handleTouchRequest:(NSDictionary *)params
{
    [Utils touch:[params[@"x"] intValue]
           withY:[params[@"y"] intValue]];
    return @"OK";
}

+(NSString *)handleConfigRequest
{
    NSMutableString *text = [[NSMutableString alloc] init];
    NSDictionary *config = [[Settings sharedInstance] config];
    if (config != nil) {
        for (id key in config) {
            [text appendFormat:@"%@=%@\n", key, config[key]];
        }
    }
    return text;
}

@end
