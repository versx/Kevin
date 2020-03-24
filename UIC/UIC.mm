//
//  UIC.cpp
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "UIC.h"

// TODO: StateManager class
// TODO: Pixel offsets in remote config
// TODO: Use https://github.com/mattstevens/RoutingHTTPServer for routes


@implementation UIC2

static HTTPServer *_httpServer;
static JobController *_jobController;

static BOOL _startup = true;
static NSNumber *_jitterCorner = @0;
static BOOL _bannedScreen = false;
static BOOL _invalidScreen = false;
//static NSLock *_lock = [[NSLock alloc] init];
//static NSNumber *_encounterDistance = @0.0;
//static NSNumber *_encounterDelay = @0.0;


#pragma mark Constructor/Deconstructor

-(id)init
{
    syslog(@"[Jarvis] [UIC] init");
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


#pragma mark App Manager

-(void)start
{
    syslog(@"[DEBUG] start");
    syslog(@"[DEBUG] Device Uuid: %@", [[Device sharedInstance] uuid]);
    syslog(@"[DEBUG] Device Model: %@", [[Device sharedInstance] model]);
    syslog(@"[DEBUG] Device OS: %@", [[Device sharedInstance] osName]);
    syslog(@"[DEBUG] Device OS Version: %@", [[Device sharedInstance] osVersion]);
    //syslog(@"[DEBUG] Device Delay Multiplier: %@", [[Device sharedInstance] multiplier]);
    
    [self setDefaultBirthDate];
    
    // Print settings
    [[Settings sharedInstance] config];
    
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
    
    // We're going to extend the base HTTPConnection class with our HttpClientConnection class.
    // This allows us to do all kinds of customizations.
    [_httpServer setConnectionClass:[HttpClientConnection class]];

    NSError *error = nil;
    if (![_httpServer start:&error]) {
        syslog(@"[ERROR] Error starting HTTP Server: %@", error);
    }

    //[self startHeartbeatLoop];
    
    //[self startUicLoop];
    
    dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
    dispatch_async(queue, ^{
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:5];
        [UIC2 startLogin];
    });

    /*
    [UIC2 ageVerification];
     
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIC2 login];
    });

    [UIC2 loginAccount];
    */
}

-(void)startHeartbeatLoop
{
    syslog(@"[DEBUG] Starting heartbeat dispatch queue...");
    bool heartbeatRunning = true;
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    data[@"uuid"] = [[Device sharedInstance] uuid];
    data[@"username"] = [[Device sharedInstance] username];
    data[@"type"] = @"heartbeat";
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:data
              blocking:false
            completion:^(NSDictionary *result) {}
    ];
    dispatch_queue_t heartbeatQueue = dispatch_queue_create("heartbeat_queue", NULL);
    dispatch_async(heartbeatQueue, ^{
        while (heartbeatRunning) {
            // Check if time since last checking was within 2 minutes, if not reboot device.
            [NSThread sleepForTimeInterval:15];
            NSDate *lastUpdate = [[DeviceState sharedInstance] lastUpdate];
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:lastUpdate];
            if (timeIntervalSince >= 120) {
                syslog(@"[ERROR] HTTP SERVER DIED. Restarting...");
                [DeviceState restart];
            } else {
                syslog(@"[INFO] Last data %f We Good", timeIntervalSince);
            }
        }
        
        // Force stop HTTP listener to prevent binding issues.
        syslog(@"[WARN] Force-stopping HTTP server.");
        [_httpServer stop];
    });
    //dispatch_release(heatbeatQueue);
}

-(void)startUicLoop
{
    syslog(@"[DEBUG] startUicLoop");
    NSDate *eggStart = [NSDate dateWithTimeInterval:-1860 sinceDate:[NSDate date]];
    syslog(@"[DEBUG] Setting eggStart...");
    [[DeviceState sharedInstance] setEggStart:eggStart];
    // Init AI
    //initJarvis();

    [self loginStateHandler];
}

-(void)setDefaultBirthDate
{
    syslog(@"[DEBUG] NSUserDefaults: %@", [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);
    syslog(@"[DEBUG] Settting default birthday key");
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"121593CC-CFEC-4F9D-BC3B-532871F77DA0"];
    [[NSUserDefaults standardUserDefaults] setInteger:19820101 forKey:@"4b9b44d8-66f5-46dc-86bb-0215bfa90f5e"];
    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"667352ee-1b19-4a2a-b531-7e10145abb35"];
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"94A7B650-0EA2-45D6-A683-28F8DED32DB0"];
    syslog(@"[DEBUG] Default birthday set");
    syslog(@"[DEBUG] NSUserDefaults: %@", [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);
}


#pragma mark State Managers

-(void)loginStateHandler
{
    syslog(@"[DEBUG] loginStateHandler");
    dispatch_queue_t loginStateQueue = dispatch_queue_create("login_state_queue", NULL);
    dispatch_async(loginStateQueue, ^{
        __block NSNumber *startupCount = @0;
        //__block BOOL birthYearSelector = false;
        __block BOOL newPlayerButton = false;
        BOOL firststart = true;
        __block BOOL menuButton = false;
        __block NSString *neededButton = @"";
        
        while (_startup) {
            if (!firststart) {
                syslog(@"[DEBUG] App still in startup...");
                [NSThread sleepForTimeInterval:1];
                while (!menuButton) {
                    NSString *username = [[Device sharedInstance] username];
                    if ([username isEqualToString:@""] || username == nil) {
                        syslog(@"[WARN] Account username is empty, requesting account and restarting...");
                        [DeviceState logout];
                        //return;
                        break;
                    }
                    //birthYearSelector = [Jarvis__ findButton:@"BirthYearSelector"];
                    //if (birthYearSelector) {
                    //    syslog(@"[DEBUG] Found birth year selector, attempting to click birth year and submit");
                        [Jarvis__ clickButton:@"BirthYearSelector"];
                        [NSThread sleepForTimeInterval:2];
                        [Jarvis__ clickButton:@"BirthYear"];
                        [NSThread sleepForTimeInterval:2];
                        [Jarvis__ clickButton:@"SubmitButton"];
                        [NSThread sleepForTimeInterval:2];
                    //}
                    newPlayerButton = [Jarvis__ clickButton:@"NewPlayerButton"]; // TODO: Rename to findButton
                    syslog(@"[DEBUG] Found NewPlayerButton: %s", newPlayerButton ? "Yes" : "No");
                    if (newPlayerButton) {
                        [Jarvis__ clickButton:@"NewPlayerButton"];
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TOKEN_USER_DEFAULT_KEY];
                        newPlayerButton = false;
                        syslog(@"[DEBUG] Started at Login Screen");
                        [NSThread sleepForTimeInterval:2];
                        bool ptcButton = false;
                        NSNumber *ptcTryCount = @0;
                        while (!ptcButton) {
                            ptcButton = [Jarvis__ clickButton:@"TrainerClubButton"]; // TODO: Rename to findButton
                            ptcTryCount = [Utils incrementInt:ptcTryCount];
                            if ([ptcTryCount intValue] > 10) {
                                newPlayerButton = [Jarvis__ clickButton:@"NewPlayerButton"];
                                ptcTryCount = @0;
                            }
                            [NSThread sleepForTimeInterval:3];
                        }
                        
                        bool usernameButton = false;
                        while (!usernameButton) {
                            usernameButton = [Jarvis__ clickButton:@"UsernameButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        [Jarvis__ typeUsername];
                        [NSThread sleepForTimeInterval:3];
                        
                        bool passwordButton = false;
                        while (!passwordButton) {
                            passwordButton = [Jarvis__ clickButton:@"PasswordButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        [Jarvis__ typePassword];
                        [NSThread sleepForTimeInterval:3];
                        
                        // TODO: touchAtPoint(180, 100);
                        [NSThread sleepForTimeInterval:3];
                        
                        bool signinButton = false;
                        while (!signinButton) {
                            signinButton = [Jarvis__ clickButton:@"SignInButton"];
                            [NSThread sleepForTimeInterval:1];
                        }
                        
                        NSNumber *delayMultiplier = @5;// TODO: [[Device sharedInstance] multiplier];
                        NSNumber *sleep = @([delayMultiplier intValue] + 15);
                        [NSThread sleepForTimeInterval:[sleep intValue]];
                    }
                    
                    /* TODO: Banned screen detection
                    _bannedScreen = [Jarvis__ findButton:@"BannedScreen"];
                    if (_bannedScreen) {
                        _bannedScreen = false;
                        syslog(@"[WARN] Account banned, switching accounts.");
                        syslog(@"[DEBUG] Username: %@", [[Device sharedInstance] username]);
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
                    */
                    /* TODO: Invalid credentials/failed to login screen detection
                    _invalidScreen = [Jarvis__ findButton:@"WrongUser"];
                    if (_invalidScreen) {
                        _invalidScreen = false;
                        syslog(@"[WARN] Wrong username, switching accounts.");
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
                    */
                    dispatch_async(dispatch_get_main_queue(), ^{
                    neededButton = [Jarvis__ getMenuButton];
                    if ([neededButton isEqualToString:@"DifferentAccountButton"]) {
                        syslog(@"[DEBUG] Found different account button, logging out...");
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
                    
                    if ([neededButton isEqualToString:@"MenuButton"]) {
                        syslog(@"[DEBUG] Found menu button, skipping login loop and starting gameStateHandler loop...");
                        menuButton = true;
                    }
                    });
                    
                    [NSThread sleepForTimeInterval:3];
                    if ([startupCount intValue] > 3) { // TODO: Max startup count before logout/pull for new account
                        syslog(@"[WARN] Stuck somewhere logging out and restarting...");
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
                syslog(@"[DEBUG] App in Main Screen stopping detection.");
                [Jarvis__ clickButton:@"TrackerButton"];
                _startup = false;
            } else {
                syslog(@"[DEBUG] First startup, waiting...");
                [NSThread sleepForTimeInterval:10];
                firststart = false;
            }
            [NSThread sleepForTimeInterval:3];
        }
    });
    //dispatch_release(loginStateQueue);
    
    //[self gameStateHandler];
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
                syslog(@"[ERROR] Failed to connect to backend!");
                [NSThread sleepForTimeInterval:5];
                [DeviceState restart];
            } else if (![(result[@"status"] ?: @"fail") isEqualToString:@"ok"]) {
                NSString *error = result[@"error"] ?: @"? (No error sent)";
                syslog(@"[ERROR] Backend returned error: %@", error);
                [[Device sharedInstance] setShouldExit:true];
            }
            
            NSDictionary *data = [result objectForKey:@"data"];
            if (data == nil) {
                syslog(@"[ERROR] Backend did not include data in response.");
                [[Device sharedInstance] setShouldExit:true];
            }
            
            if (!(data[@"assigned"] ?: false)) {
                syslog(@"[WARN] Device is not assigned to an instance!");
                [[Device sharedInstance] setShouldExit:true];
            }
            
            NSString *firstWarningTimestamp = data[@"first_warning_timestamp"];
            if (firstWarningTimestamp != nil && ![firstWarningTimestamp isEqualToString:@"<null>"]) {
                NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp intValue]];
                [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
            }
            
            syslog(@"[INFO] Connected to backend successfully!");
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
                        syslog(@"[DEBUG] Got account %@ level %@ from backend.", username, level);
                    } else {
                        syslog(@"[ERROR] Failed to get account and not logged in.");
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
                    syslog(@"[DEBUG] StartupLocation: %@", startupLocation);
                    NSNumber *firstWarningTimestamp = data[@"first_warning_timestamp"];
                    if (firstWarningTimestamp != nil) {
                        NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                        [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
                    }
                } else {
                    syslog(@"[WARN] Failed to get account and not logged in.");
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
                            syslog(@"[ERROR] Failed to get job 10 times in a row. Exiting...");
                            [[Device sharedInstance] setShouldExit:true];
                        } else {
                            syslog(@"[ERROR] Failed to get a job.");
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
                                syslog(@"[WARN] Account is outside min/max level. Current: %@ Min/Max: %@/%@. Logging out!", currentLevel, minLevel, maxLevel);
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
                            syslog(@"[DEBUG] [STATUS] Pokemon");
                            [_jobController handlePokemonJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_raid"]) {
                            syslog(@"[DEBUG] [STATUS] Raid");
                            [_jobController handleRaidJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_quest"]) {
                            syslog(@"[DEBUG] [STATUS] Quest/Leveling");
                            [_jobController handleQuestJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"switch_account"]) {
                            syslog(@"[DEBUG] [STATUS] Switching Accounts");
                            [_jobController handleSwitchAccount:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"leveling"]) {
                            syslog(@"[DEBUG] [STATUS] Leveling");
                            [_jobController handleLeveling:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_iv"]) {
                            syslog(@"[DEBUG] [STATUS] IV");
                            [_jobController handleIVJob:action withData:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"gather_token"]) {
                            syslog(@"[DEBUG] [STATUS] Token");
                            [_jobController handleGatherToken:action withData:data hasWarning:hasWarning];
                        } else {
                            syslog(@"[WARN] Unknown Action: %@", action);
                        }
                        
                        NSNumber *emptyGmoCount = [[DeviceState sharedInstance] emptyGmoCount];
                        NSNumber *maxEmptyGMO = [[Settings sharedInstance] maxEmptyGMO];
                        if (emptyGmoCount >= maxEmptyGMO) {
                            syslog(@"[WARN] Got Empty GMO %@ times in a row. Restarting...", emptyGmoCount);
                            [DeviceState restart];
                        }
                        
                        NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
                        if (failedCount >= [[Settings sharedInstance] maxFailedCount]) {
                            syslog(@"[ERROR] Failed %@ times in a row. Restarting...", failedCount);
                            [DeviceState restart];
                        }
                    } else {
                        [[DeviceState sharedInstance] setFailedGetJobCount:0];
                        syslog(@"[WARN] No job left (Result: %@)", result);
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
            syslog(@"[DEBUG] Level from RDM: %@ quests: %@", [[Device sharedInstance] level], quests);
        }
        
        syslog(@"[DEBUG] [RES1] inArea: %s level: %@ nearby: %@ wild: %@ quests: %@ encounters: %@ plat: %@ plon: %@ encounterResponseId: %@ tarlat: %@ tarlon: %@ emptyGMO: %s invalidGMO: %s containsGMO: %s", (inArea ? "Yes" : "No"), level, nearby, wild, quests, encounters, pokemonLat, pokemonLon, pokemonEncounterIdResult, targetLat, targetLon, (onlyEmptyGmos ? "Yes" : "No"), (onlyInvalidGmos ? "Yes" : "No"), (containsGmo ? "Yes" : "No"));
        syslog(@"[DEBUG] SpinFortLat: %@ SpinFortLon: %@", spinFortLat, spinFortLon);

        //NSNumber *itemDistance = @10000.0;
        if (([spinFortId isEqualToString:@""] || spinFortId == nil) && [spinFortLat doubleValue] != 0.0) {
            CLLocation *fortLocation = [Utils createCoordinate:[spinFortLat doubleValue] lon:[spinFortLon doubleValue]];
            NSNumber *itemDistance = [NSNumber numberWithDouble:[fortLocation distanceFromLocation:currentLoc]];
            syslog(@"[DEBUG] ItemDistance: %@", itemDistance);
        }
        
        if (onlyInvalidGmos) {
            [[DeviceState sharedInstance] setWaitForData:false];
            toPrint = @"Got GMO but it was malformed. Skipping.";
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
                            toPrint = @"Got Data and found Pokemon";
                        } else {
                            toPrint = @"Got Data but did not find Pokemon";
                        }
                    } else {
                        toPrint = @"Got Data without Pokemon";
                    }
                } else if ([[DeviceState sharedInstance] waitRequiresPokemon]) {
                    if ([pokemonFoundCount intValue] > 0) {
                        toPrint = @"Got Data with Pokemon";
                        [[DeviceState sharedInstance] setWaitForData:false];
                    } else {
                        toPrint = @"Got Data without Pokemon";
                    }
                } else {
                    toPrint = @"Got Data";
                    [[DeviceState sharedInstance] setWaitForData:false];
                }
            } else if (onlyEmptyGmos && !_startup) {
                NSNumber *emptyGmoCount = [[DeviceState sharedInstance] emptyGmoCount];
                [[DeviceState sharedInstance] setEmptyGmoCount:emptyGmoCount];
                toPrint = @"Got Empty Data";
            } else {
                [[DeviceState sharedInstance] setEmptyGmoCount:0];
                toPrint = @"Got Data outside Target-Area";
            }
        } else {
            toPrint = @"Got Data without GMO";
        }

        if (![[DeviceState sharedInstance] gotQuest] && quests != 0) {
            [[DeviceState sharedInstance] setGotQuest:true];
            [[DeviceState sharedInstance] setGotQuestEarly:true];
        }
        
        if (![[DeviceState sharedInstance] gotIV] && encounters != 0) {
            [[DeviceState sharedInstance] setGotIV:true];
        }
        
        syslog(@"[DEBUG] Handle data response: %@", toPrint);
    }];
    NSString *response = [Utils toJsonString:data withPrettyPrint:false];
    return response;
}

+(NSString *)handleTouchRequest:(NSDictionary *)params
{
    //[Utils touch:[params[@"x"] intValue]
    //       withY:[params[@"y"] intValue]];
    //DeviceCoordinate *newPlayer = [[DeviceConfig sharedInstance] loginNewPlayer];
    [JarvisTestCase touch:[params[@"x"] intValue]
                    withY:[params[@"y"] intValue]
    ];
    return @"OK";
}

+(NSString *)handleTypeRequest:(NSDictionary *)params
{
    [JarvisTestCase type:params[@"text"]];
    return @"OK";
}

+(NSString *)handleSwipeRequest
{
    [JarvisTestCase swipe];
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

+(NSString *)handlePixelRequest:(NSDictionary *)params
{
    syslog(@"[DEBUG] handlePixelRequest: %@", params);
    //__block NSString *response;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        syslog(@"[DEBUG] Screenshot taken");
        DeviceCoordinate *startupLoggedOut = [[DeviceConfig sharedInstance] startupLoggedOut];
        UIColor *startupColor = [image getPixelColor:[startupLoggedOut x] withY:[startupLoggedOut y]];
        syslog(@"[DEBUG] startup pixel color %@", startupColor);
        
        NSNumber *x = params[@"x"];
        NSNumber *y = params[@"y"];
        UIColor *color = [image getPixelColor:[x intValue] withY:[y intValue]];
        if (color == nil) {
            syslog(@"[ERROR] Failed to get rgbAtLocation x=%@ y=%@", x, y);
        } else {
            syslog(@"[DEBUG] rgbAtLocation: x=%@ y=%@ color=%@", x, y, color);
        }
    });
    //response = [NSString stringWithFormat:@"[DEBUG] Pixel x=%@ y=%@ color=%@", x, y, color];
    //syslog(@"%@", response);
    return @"OK";
}

+(NSString *)handleTestRequest:(NSDictionary *)params
{
    syslog(@"[DEBUG] handleTestRequest: %@", params);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        if ([image rgbAtLocation:[[DeviceConfig sharedInstance] mainScreenPokeballRed]
                      betweenMin:[[ColorOffset alloc] init:0.15 green:0.33 blue:0.17]
                          andMax:[[ColorOffset alloc] init:0.25 green:0.43 blue:0.27]]) {
            syslog(@"[DEBUG] Main screen pixel found");
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startup]
                             betweenMin:[[ColorOffset alloc] init:0.0 green:0.75 blue:0.55]
                                 andMax:[[ColorOffset alloc] init:1.0 green:0.90 blue:0.70]]) {
            syslog(@"[DEBUG] Startup pixel found");
        } else {
            syslog(@"[DEBUG] Nothing found");
        }
    });
    
    //[self ageVerification];
    //[self loginAccount];
    
    return @"OK";
}

+(void)login
{
    syslog(@"[DEBUG] Preparing init postRequest payload");
    NSMutableDictionary *initData = [[NSMutableDictionary alloc] init];
    initData[@"uuid"] = [[Device sharedInstance] uuid];
    initData[@"username"] = [[Device sharedInstance] username];
    initData[@"type"] = @"init";
    syslog(@"[DEBUG] Sending init postRequest: %@", initData);
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:initData
              blocking:true /*true*/
            completion:^(NSDictionary *result) {
        syslog(@"[DEBUG] init postRequest sent, response %@", result);
        if (result == nil) {
            syslog(@"[ERROR] Failed to connect to Backend!");
            // TODO: shouldExit = true;
            sleep(1); // TODO: DelayMultiplier
            return;
        } else if (![result[@"status"] isEqualToString:@"ok"]) {
            NSString *error = result[@"error"] ?: @"? (no error sent)";
            syslog(@"[ERROR] Backend returned an error: %@", error);
            // TODO: shouldExit = true;
            sleep(1); // TODO: DelayMultiplier
            return;
        }
        NSDictionary *data = [result objectForKey:@"data"];
        if (data == nil) {
            syslog(@"[ERROR] Backend did not include any data!");
            // TODO: shouldExit = true;
            sleep(1); // TODO: DelayMultiplier
            return;
        }
        if (![data[@"assigned"] boolValue]) {
            syslog(@"[ERROR] Device is not assigned to an instance!");
            // TODO: shouldExit = true;
            sleep(1); // TODO: DelayMultiplier
            return;
        }
        syslog(@"[INFO] Connected to Backend successfully!");
    }];
    
    syslog(@"[DEBUG] Checking if username is empty and account manager is enabled");
    NSString *username = [[Device sharedInstance] username];
    if ((username == nil || [username isEqualToString:@""]) && [[Settings sharedInstance] enableAccountManager]) {
        NSMutableDictionary *getAccountData = [[NSMutableDictionary alloc] init];
        getAccountData[@"uuid"] = [[Device sharedInstance] uuid];
        getAccountData[@"username"] = username;
        getAccountData[@"min_level"] = [[Device sharedInstance] minLevel];
        getAccountData[@"max_level"] = [[Device sharedInstance] maxLevel];
        getAccountData[@"type"] = @"get_account";
        syslog(@"[DEBUG] Sending get_account request: %@", getAccountData);
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:getAccountData
                  blocking:true /*true*/
                completion:^(NSDictionary *result) {
            syslog(@"[DEBUG] get_account postRequest sent, response %@", result);
            NSDictionary *data = [result objectForKey:@"data"];
            NSString *user = data[@"username"];
            NSString *pass = data[@"password"];
            if (data == nil || user == nil || pass == nil) {
                syslog(@"[ERROR] Failed to get account and not logged in.");
                //shouldExit = true;
                return;
            }
            [[Device sharedInstance] setUsername:user];
            [[Device sharedInstance] setPassword:pass];
            //[[Device sharedInstance] setNewLogIn:true];
            [[Device sharedInstance] setIsLoggedIn:false];
            
            // TODO: Check first_warning_timestamp
            
            syslog(@"[INFO] Got account %@ from backend.", user);
        }];
    }
        
    sleep(3);
    
    // TODO: Init global DeviceConfig
    // TODO: login
    __block bool loaded = false;
    __block int count = 0;
    syslog(@"[DEBUG] Starting login loop");
    while (!loaded) {
        //dispatch_async(dispatch_get_main_queue(), ^{
        syslog(@"[DEBUG] Taking screenshot");
        UIImage *image = [Utils takeScreenshot];
        syslog(@"[DEBUG] Screenshot taken");
        if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startup]
                      betweenMin:[[ColorOffset alloc] init:0.0 green:0.75 blue:0.55]
                          andMax:[[ColorOffset alloc] init:1.0 green:0.90 blue:0.70]]) {
            syslog(@"[DEBUG] Tried to log in but already logged in.");
            [[DeviceState sharedInstance] setNeedsLogout:true];
            [[Device sharedInstance] setIsLoggedIn:true];
            // TODO: [[DeviceState sharedInstance] setNewLogIn:false];
            return;
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startupLoggedOut] //0.0313726 0.796078 1 1
                             betweenMin:[[ColorOffset alloc] init:0.95 green:0.75 blue:0.0]
                                 andMax:[[ColorOffset alloc] init:1.00 green:0.85 blue:0.1]] ||
                   [image rgbAtLocation:[[DeviceConfig sharedInstance] startupLoggedOut]
                             betweenMin:[[ColorOffset alloc] init:0.02 green:0.78 blue:0.9]
                                 andMax:[[ColorOffset alloc] init:0.04 green:0.80 blue:1.0]]) {
            syslog(@"[DEBUG] App started in login screen.");
            loaded = true;
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] ageVerification]
                             betweenMin:[[ColorOffset alloc] init:0.15 green:0.33 blue:0.17]
                                 andMax:[[ColorOffset alloc] init:0.25 green:0.43 blue:0.27]]) {
            syslog(@"[DEBUG] Age verification.");
            [self ageVerification];
        } else {//else if (/*AtteptTos()*/]
            syslog(@"[DEBUG] Nothing detected");
        }
        count++;
        if (count == 30 && !loaded) {
            count = 0;
            [DeviceState restart];
            sleep(1); // TODO: DelayMultiplier
        }
        //[image release];
        sleep(1 * 5); // TODO: DelayMultipliers
        /*
        dispatch_async(dispatch_get_main_queue(), ^{
        if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startup]
                      betweenMin:[[ColorOffset alloc] init:0.0 green:0.75 blue:0.55]
                          andMax:[[ColorOffset alloc] init:1.0 green:0.90 blue:0.70]]) {
            syslog(@"[DEBUG] Tried to log in but already logged in.");
            [[DeviceState sharedInstance] setNeedsLogout:true];
            [[Device sharedInstance] setIsLoggedIn:true];
            // TODO: [[DeviceState sharedInstance] setNewLogIn:false];
            return;
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startupLoggedOut] //0.0313726 0.796078 1 1
                             betweenMin:[[ColorOffset alloc] init:0.95 green:0.75 blue:0.0]
                                 andMax:[[ColorOffset alloc] init:1.0 green:0.85 blue:0.1]] ||
                   [image rgbAtLocation:[[DeviceConfig sharedInstance] startupLoggedOut]
                             betweenMin:[[ColorOffset alloc] init:0.02 green:0.78 blue:0.9]
                                 andMax:[[ColorOffset alloc] init:0.04 green:0.80 blue:1.0]]) {
            syslog(@"[DEBUG] App started in login screen.");
            loaded = true;
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] ageVerification]
                             betweenMin:[[ColorOffset alloc] init:0.15 green:0.33 blue:0.17]
                                 andMax:[[ColorOffset alloc] init:0.25 green:0.43 blue:0.27]]) {
            syslog(@"[DEBUG] Age verification.");
            [self ageVerification];
        } else {//else if (AtteptTos()]
            syslog(@"[DEBUG] Nothing detected");
        }
        count++;
        if (count == 30 && !loaded) {
            count = 0;
            [DeviceState restart];
            sleep(1); // TODO: DelayMultiplier
        }
        sleep(1 * 10); // TODO: DelayMultipliers
        });
        */
    }
    /*
    if ([NSThread isMainThread]) {
        syslog(@"[DEBUG] Already main thread");
        block();
    } else {
        syslog(@"[DEBUG] Different thread");
        dispatch_async(dispatch_get_main_queue(), block);
    }
    */
    if (![[Settings sharedInstance] enableAccountManager] ||
        [[Device sharedInstance] shouldExit]) {
        return;
    }
    
    [self loginAccount];
        
    // TODO: Move age verification stuff here
    // postRequest init
    // if username is null postRequest get_account
    // init device config
    // check startup pixels
    // check age verification
    // type username
    // type password
    // check 'part4LoginEnd' pixels
    // tuts
    // part8Main aka startHeartbeatLoop
    // runLoop aka gameStateHandler
}

+(void)startLogin
{
    // TODO: Check for startup NIA screen, wait until.
    __block bool isAgeVerification = false;
    __block bool isStartupLoggedOut = false;
    __block bool isStartup = false;
    __block bool isStartupLogo = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        isAgeVerification = [image rgbAtLocation:[[DeviceConfig sharedInstance] ageVerification]
                                      betweenMin:[[ColorOffset alloc] init:0.15 green:0.33 blue:0.17]
                                          andMax:[[ColorOffset alloc] init:0.25 green:0.43 blue:0.27]];
        isStartupLoggedOut = [image rgbAtLocation:[[DeviceConfig sharedInstance] startupLoggedOut] //0.0313726 0.796078 1 1
                                       betweenMin:[[ColorOffset alloc] init:0.95 green:0.75 blue:0.0]
                                           andMax:[[ColorOffset alloc] init:1.00 green:0.85 blue:0.1]] ||
                             [image rgbAtLocation:[[DeviceConfig sharedInstance] startupLoggedOut]
                                       betweenMin:[[ColorOffset alloc] init:0.02 green:0.78 blue:0.9]
                                           andMax:[[ColorOffset alloc] init:0.04 green:0.80 blue:1.0]];
        isStartup = [image rgbAtLocation:[[DeviceConfig sharedInstance] startup]
                              betweenMin:[[ColorOffset alloc] init:0.0 green:0.75 blue:0.55]
                                  andMax:[[ColorOffset alloc] init:1.0 green:0.90 blue: 0.70]];
        /*
        isStartupLogo = [image rgbAtLocation:[[DeviceConfig sharedInstance] startupLogo]
                                  betweenMin:[[ColorOffset alloc] init:1.0 green:1.0 blue:1.0]
                                      andMax:[[ColorOffset alloc] init:1.0 green:1.0 blue:1.0]];
        */
        //[image release];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if (isAgeVerification) {
        syslog(@"[DEBUG] Age verification screen.");
        [UIC2 ageVerification];
        [UIC2 loginAccount];
    } else if (isStartupLoggedOut) {
        syslog(@"[DEBUG] App started in login screen.");
        [UIC2 loginAccount];
    } else if (isStartup) {
        syslog(@"[DEBUG] Tried to log in but already logged in.");
        // TODO: Wait, click away caution, weather, warnings, etc
    } else if (isStartupLogo) {
        syslog(@"[DEBUG] Startup logo found, waiting and trying again.");
        sleep(2); // TODO: DelayMultiplier
        [UIC2 startLogin];
    } else {
        // TODO: StartupLogo sleep(1); // TODO: DelayMultiplier [UIC2 startLogin];
        syslog(@"[ERROR] Nothing found");
    }
}

+(void)ageVerification
{
    int sleepDelay = 1; // TODO: DelayMultiplier
    // TODO: Check for age verification pixel
    syslog(@"[DEBUG] Is age verification, selecting year selector");
    DeviceCoordinate *ageVerificationYear = [[DeviceConfig sharedInstance] ageVerificationYear];
    [JarvisTestCase touch:[ageVerificationYear tapX]
                    withY:[ageVerificationYear tapY]];
    sleep(sleepDelay);
    syslog(@"[DEBUG] Tapping year 2007");
    DeviceCoordinate *ageVerificationYear2007 = [[DeviceConfig sharedInstance] ageVerificationYear2007];
    [JarvisTestCase touch:[ageVerificationYear2007 tapX]
                    withY:[ageVerificationYear2007 tapY]];
    sleep(sleepDelay);
    syslog(@"[DEBUG] Tapping age verification confirmation button");
    DeviceCoordinate *ageVerification = [[DeviceConfig sharedInstance] ageVerification];
    [JarvisTestCase touch:[ageVerification tapX]
                    withY:[ageVerification tapY]];
    sleep(sleepDelay);
}

+(void)loginAccount
{
    int sleepDelay = 1; // TODO: DelayMultiplier
    sleep(sleepDelay);
    
    // Click 'New Player' button
    DeviceCoordinate *loginNewPlayer = [[DeviceConfig sharedInstance] loginNewPlayer];
    syslog(@"[DEBUG Tapping new player button %@", loginNewPlayer);
    [JarvisTestCase touch:[loginNewPlayer tapX]
                    withY:[loginNewPlayer tapY]];
    sleep(2);
    
    // Click Pokemon Trainer Club button
    DeviceCoordinate *loginPTC = [[DeviceConfig sharedInstance] loginPTC];
    syslog(@"[DEBUG] Tapping PTC button %@", loginPTC);
    [JarvisTestCase touch:[loginPTC tapX]
                    withY:[loginPTC tapY]];
    sleep(2);
    
    // Click Username text field
    DeviceCoordinate *loginUsernameTextfield = [[DeviceConfig sharedInstance] loginUsernameTextfield];
    syslog(@"[DEBUG] Tapping username text field %@", loginUsernameTextfield);
    [JarvisTestCase touch:[loginUsernameTextfield tapX]
                    withY:[loginUsernameTextfield tapY]];
    sleep(sleepDelay);
    
    // Type account username
    syslog(@"[DEBUG] Typing username %@", [[Device sharedInstance] username]);
    //[JarvisTestCase type:[[Device sharedInstance] username]];
    [Jarvis__ typeUsername];
    sleep(sleepDelay);
    
    // Click Password text field
    DeviceCoordinate *loginPasswordTextfield = [[DeviceConfig sharedInstance] loginPasswordTextfield];
    syslog(@"[DEBUG] Tappng password text field %@", loginPasswordTextfield);
    [JarvisTestCase touch:[loginPasswordTextfield tapX]
                    withY:[loginPasswordTextfield tapY]];
    sleep(sleepDelay);
    
    // Type account password
    syslog(@"[DEBUG] Typing password %@", [[Device sharedInstance] password]);
    //[JarvisTestCase type:[[Device sharedInstance] password]];
    [Jarvis__ typePassword];
    sleep(sleepDelay);
    
    // Click Config login button
    DeviceCoordinate *loginConfirm = [[DeviceConfig sharedInstance] loginConfirm];
    syslog(@"[DEBUG] Tapping confirm login %@", loginConfirm);
    [JarvisTestCase touch:[loginConfirm tapX]
                    withY:[loginConfirm tapY]];
    sleep(sleepDelay);
    
    // TODO: Check screens
}

@end
