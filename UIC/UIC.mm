//
//  UIC.cpp
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "UIC.h"

// TODO: Fix jitter
// TODO: Break out UIC into more classes
// TODO: Tap news away
// TODO: Level check
// TODO: Make dispatch queues global references
// TODO: Egg Deploy
// TODO: Fix integer increments/decrements emptyGMOCount, etc
// TODO: Remove PTFakeTouch
// TODO: StateManager class
// TODO: Pixel offsets in remote config
// TODO: Use https://github.com/mattstevens/RoutingHTTPServer for routes
// TODO: https://developer.apple.com/documentation/xctest/xctestcase/1496273-adduiinterruptionmonitorwithdesc
// REFERENCE: Find pixel location from screenshot - http://nicodjimenez.github.io/boxLabel/annotate.html

@implementation UIC2

static HTTPServer *_httpServer;
static JobController *_jobController;

static BOOL _dataStarted = false;
static BOOL _startup = true;
static NSNumber *_jitterCorner = @0;
//static NSLock *_lock = [[NSLock alloc] init];


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
    syslog(@"[DEBUG] Device Uuid: %@", [[Device sharedInstance] uuid]);
    syslog(@"[DEBUG] Device Model: %@", [[Device sharedInstance] model]);
    syslog(@"[DEBUG] Device OS: %@", [[Device sharedInstance] osName]);
    syslog(@"[DEBUG] Device OS Version: %@", [[Device sharedInstance] osVersion]);
    syslog(@"[DEBUG] Device Delay Multiplier: %@", [[Device sharedInstance] multiplier]);
    
    //[self setDefaultBirthDate];
    
    // Print settings
    [[Settings sharedInstance] config];
    
    //JarvisTestCase *jarvis = [[JarvisTestCase alloc] init];
    //[jarvis runTest];
    //[jarvis registerUIInterruptionHandler:@"System Dialog"];
    
    // Initialize job controller
    _jobController = [[JobController alloc] init];

    // Initalize our http server
    _httpServer = [[HTTPServer alloc] init];
    //[_httpServer setType:@"_http._tcp."];
    [_httpServer setPort:[[[Settings sharedInstance] port] intValue]];
    
    // We're going to extend the base HTTPConnection class with our HttpClientConnection class.
    // This allows us to do all kinds of customizations.
    [_httpServer setConnectionClass:[HttpClientConnection class]];

    NSError *error = nil;
    if (![_httpServer start:&error]) {
        syslog(@"[ERROR] Error starting HTTP Server: %@", error);
    }

    syslog(@"[DEBUG] NSUserDefaults: %@", [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);

    [[DeviceState sharedInstance] setEggStart:[NSDate dateWithTimeInterval:-1860 sinceDate:[NSDate date]]];
    
    [self login];
    [self startHeartbeatLoop]; // TODO: Start heartbeat first time after receiving data.
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

/*
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
*/

+(void)initializeWithBackend
{
    NSMutableDictionary *initData = [[NSMutableDictionary alloc] init];
    initData[@"uuid"] = [[Device sharedInstance] uuid];
    initData[@"username"] = [[Device sharedInstance] username];
    initData[@"type"] = @"init";
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:initData
              blocking:true
            completion:^(NSDictionary *result) {
        syslog(@"[DEBUG] Response from init: %@", result);
        if (result == nil) {
            syslog(@"[ERROR] Failed to connect to backend!");
            [[Device sharedInstance] setShouldExit:true];
            [NSThread sleepForTimeInterval:5];
            [DeviceState restart];
            return;
        } else if (![(result[@"status"] ?: @"fail") isEqualToString:@"ok"]) {
            NSString *error = result[@"error"] ?: @"? (No error sent)";
            syslog(@"[ERROR] Backend returned error: %@", error);
            [[Device sharedInstance] setShouldExit:true];
            sleep(1);
            return;
        }
        
        NSDictionary *data = [result objectForKey:@"data"];
        if (data == nil) {
            syslog(@"[ERROR] Backend did not include data in response.");
            [[Device sharedInstance] setShouldExit:true];
            sleep(1);
            return;
        }
        
        if (!(data[@"assigned"] ?: false)) {
            syslog(@"[WARN] Device is not assigned to an instance!");
            [[Device sharedInstance] setShouldExit:true];
            sleep(1);
            return;
        }
        
        // TODO: firstWarningTimestamp
        /*
        NSString *firstWarningTimestamp = data[@"first_warning_timestamp"];
        syslog(@"[DEBUG] Checking firstWarningTimestamp");
        if (firstWarningTimestamp != nil && ![firstWarningTimestamp isEqualToString:@"<null>"]) {
            NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp intValue]];
            [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
        }
        */
        
        syslog(@"[INFO] Connected to backend successfully!");
        [[Device sharedInstance] setShouldExit:false];
    }];
    
    if ([[Device sharedInstance] shouldExit]) {
        [[Device sharedInstance] setShouldExit:false];
        [NSThread sleepForTimeInterval:5];
        [DeviceState restart];
    }
}

+(void)getAccountFromBackend
{
    syslog(@"[INFO] Sending 'get_account' post request.");
    if (([[[Device sharedInstance] username] isNullOrEmpty] ||
         [[[Device sharedInstance] username] isEqualToString:@"fail"]) &&
         [[Settings sharedInstance] enableAccountManager]) {
        NSMutableDictionary *getAccountData = [[NSMutableDictionary alloc] init];
        getAccountData[@"uuid"] = [[Device sharedInstance] uuid];
        getAccountData[@"username"] = [[Device sharedInstance] username];
        getAccountData[@"min_level"] = [[Device sharedInstance] minLevel];
        getAccountData[@"max_level"] = [[Device sharedInstance] maxLevel];
        getAccountData[@"type"] = @"get_account";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:getAccountData
                  blocking:true
                completion:^(NSDictionary *result) {
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
                // TODO: firstWarningTimestamp
                /*
                NSNumber *firstWarningTimestamp = data[@"first_warning_timestamp"];
                if (firstWarningTimestamp != nil) {
                    NSDate *firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                    [[DeviceState sharedInstance] setFirstWarningDate:firstWarningDate];
                }
                */
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
}


#pragma mark State Managers

+(void)getJobHandler
{
    // TODO: qos: background dispatch
    dispatch_queue_t gameStateQueue = dispatch_queue_create("game_state_queue", NULL);
    dispatch_async(gameStateQueue, ^{
        bool hasWarning = false;
        [[DeviceState sharedInstance] setFailedGetJobCount:@0];
        [[DeviceState sharedInstance] setFailedCount:@0];
        [[DeviceState sharedInstance] setEmptyGmoCount:@0];
        [[DeviceState sharedInstance] setNoQuestCount:@0];
        //_noEncounterCount = 0;

        // Grab an account from the backend controller.
        [UIC2 getAccountFromBackend];
        
        syslog(@"[INFO] Starting job handler.");
        while (![[Device sharedInstance] shouldExit]) {
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            __block NSDictionary *data = nil;
            if ([[DeviceState sharedInstance] needsLogout]) {
                syslog(@"[INFO] Logging out...");
                //self.lock.lock();
                CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                //self.lock.unlock();
                [DeviceState logout];
            }
            NSMutableDictionary *jobData = [[NSMutableDictionary alloc] init];
            jobData[@"uuid"] = [[Device sharedInstance] uuid];
            jobData[@"username"] = [[Device sharedInstance] username];
            jobData[@"type"] = @"get_job";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                          dict:jobData
                      blocking:true
                    completion:^(NSDictionary *result) {
                syslog(@"[DEBUG] get_job response: %@", result);
                if (result == nil) {
                    NSNumber *failedGetJobCount = [[DeviceState sharedInstance] failedGetJobCount];
                    if ([failedGetJobCount intValue] == 10) {
                        syslog(@"[ERROR] Failed to get job 10 times in a row. Exiting...");
                        //[[Device sharedInstance] setShouldExit:true];
                        return;
                    } else {
                        syslog(@"[ERROR] Failed to get a job.");
                        return;
                    }
                } else if ([[Settings sharedInstance] enableAccountManager]) {
                    data = result[@"data"];
                    if (data != nil) {
                        NSNumber *minLevel = data[@"min_level"];
                        NSNumber *maxLevel = data[@"max_level"];
                        [[Device sharedInstance] setMinLevel:minLevel];
                        [[Device sharedInstance] setMaxLevel:maxLevel];
                        NSNumber *currentLevel = [[Device sharedInstance] level];
                        syslog(@"[DEBUG] Current level %@ (Min: %@, Max: %@)", currentLevel, minLevel, maxLevel);
                        /*
                        if (currentLevel != 0 && (currentLevel < minLevel || currentLevel > maxLevel)) {
                            syslog(@"[WARN] Account is outside min/max level. Current: %@ Min/Max: %@/%@. Logging out!", currentLevel, minLevel, maxLevel);
                            //self.lock.lock();
                            CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                            [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                            [DeviceState logout];
                            //self.lock.unlock();
                        }
                        */
                    }
                }
                
                [[DeviceState sharedInstance] setFailedGetJobCount:0];
                if (data == nil) {
                    syslog(@"[WARN] No job left (Result: %@)", result);
                    [[DeviceState sharedInstance] setFailedGetJobCount:0];
                    [NSThread sleepForTimeInterval:5];
                    return;
                }

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
                    syslog(@"[WARN] Unknown action received: %@", action);
                }
                
                dispatch_semaphore_signal(sem);
                
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
                sleep(2);
            }];
            
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            sleep(3);
        }
    });
}


#pragma mark Request Handlers
// TODO: Make request handler class.

+(NSString *)handleLocationRequest
{
    NSMutableDictionary *responseData = [[NSMutableDictionary alloc] init];
    //self.lock.lock();
    CLLocation *currentLoc = [[DeviceState sharedInstance] currentLocation];
    syslog(@"[DEBUG] [LOC] currentLocation: %@", currentLoc);
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
            syslog(@"[DEBUG] [LOC] Jittered Location: %@, %@ (jitterCorner: %@", currentLat, currentLon, _jitterCorner);
            responseData[@"latitude"] = currentLat;
            responseData[@"longitude"] = currentLon;
            responseData[@"lat"] = currentLat;
            responseData[@"lng"] = currentLon;

            //"scan_iv", "scan_pokemon"
            if ([[[Device sharedInstance] level] intValue] >= 30) {
                responseData[@"actions"] = @[@"pokemon"];
            } else {
                responseData[@"actions"] = @[@"pokemon"]; // TODO: TESTING ONLY Return empty @""
            }
        } else {
            // raids, quests
            //self.lock.unlock();
            NSNumber *currentLat = [NSNumber numberWithDouble:currentLoc.coordinate.latitude];
            NSNumber *currentLon = [NSNumber numberWithDouble:currentLoc.coordinate.longitude];
            responseData[@"latitude"] = currentLat;
            responseData[@"longitude"] = currentLon;
            responseData[@"lat"] = currentLat;
            responseData[@"lng"] = currentLon;
            
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
            } else if (!ultraQuests && [action isEqualToString:@"scan_quest"]) {
                // Auto-spinning should only happen when ultraQuests is
                // set and the instance is scan_quest type
                if ([[[Device sharedInstance] level] intValue] >= 30) {
                    responseData[@"actions"] = @[@"pokemon"];
                } else {
                    responseData[@"actions"] = @[@""];
                }
            } else if ([action isEqualToString:@"leveling"]) {
                responseData[@"actions"] = @[@"pokestop"];
            } else if ([action isEqualToString:@"scan_raid"]) {
                // Raid instances do not need IV encounters, Use scan_pokemon
                // type if you want to encounter while scanning raids.
                responseData[@"actions"] = @[@""];
            }
        }
    }

    NSString *response = [Utils toJsonString:responseData withPrettyPrint:false];
    syslog(@"[DEBUG] [LOC] %@", response);
    return response;
}

+(NSString *)handleDataRequest:(NSDictionary *)params
{
    CLLocation *currentLocation = [[DeviceState sharedInstance] currentLocation];
    if (currentLocation == nil) {
        syslog(@"[ERROR] currentLocation is null");
        //return @"Error"; // TODO: Return json response { status: error }
    }
    [[DeviceState sharedInstance] setLastUpdate:[NSDate date]];
    CLLocation *currentLoc = [Utils createCoordinate:currentLocation.coordinate.latitude lon: currentLocation.coordinate.longitude];
    //NSNumber *targetMaxDistance = _targetMaxDistance;
    NSString *pokemonEncounterId = [[DeviceState sharedInstance] pokemonEncounterId];
    NSMutableDictionary *data = [params mutableCopy];
    data[@"lat_target"] = @(currentLoc.coordinate.latitude);
    data[@"lon_target"] = @(currentLoc.coordinate.longitude);
    data[@"target_max_distance"] = [[Settings sharedInstance] targetMaxDistance];
    data[@"username"] = [[Device sharedInstance] username] ?: @"";
    data[@"pokemon_encounter_id"] = pokemonEncounterId ?: @"";
    data[@"uuid"] = [[Device sharedInstance] uuid];
    data[@"ptcToken"] = [[Device sharedInstance] ptcToken] ?: @"";
    
    [Utils postRequest:[[Settings sharedInstance] backendRawUrl]
                  dict:data
              blocking:false
            completion:^(NSDictionary *result) {
        syslog(@"[DEBUG] Raw data response: %@", result);
        if (data == nil) {
            syslog(@"[ERROR] Raw response nil");
            return;
        }
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
        if ([spinFortId isNullOrEmpty] && [spinFortLat doubleValue] != 0.0) {
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
                [[DeviceState sharedInstance] setEmptyGmoCount:@0];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        syslog(@"[DEBUG] Screenshot taken");
        NSNumber *x = params[@"x"];
        NSNumber *y = params[@"y"];
        UIColor *color = [image getPixelColor:[x intValue] withY:[y intValue]];
        if (color == nil) {
            syslog(@"[ERROR] Failed to get rgbAtLocation x=%@ y=%@", x, y);
        } else {
            syslog(@"[DEBUG] rgbAtLocation: x=%@ y=%@ color=%@", x, y, color);
        }
    });
    return @"OK";
}

+(NSString *)handleTestRequest:(NSDictionary *)params
{
    syslog(@"[DEBUG] handleTestRequest: %@", params);
    /*
    //dispatch_async(dispatch_get_main_queue(), ^{
        // TODO: Setup timer to check if button exists
        //[self findAndClick];
        //[Utils showAlert:self withMessage:@"This is a test alert"];
        //XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.nianticlabs.pokemongo"];
        //[app launch];
        //[app terminate];
        //XCUIElementQuery *buttons = [app buttons];
        //XCUIElement *allowButton = [buttons objectForKeyedSubscript:@"Allow"];
        //bool btnExists = [allowButton exists];
        //syslog(@"[DEBUG] Allow button exists %@", btnExists ? @"Yes" : @"No");
        //[allowButton tap];
    //});
    */
    
    return @"OK";
}


#pragma mark Login Handlers
// TODO: Make class

-(void)login
{
    [UIC2 initializeWithBackend];
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSString *username = [[Device sharedInstance] username];
    syslog(@"[DEBUG] Checking if username is empty and account manager is enabled: %@", username);
    if ([username isNullOrEmpty] && [[Settings sharedInstance] enableAccountManager]) {
        syslog(@"[DEBUG] Account username is empty and account manager is enabled, starting account request...");
        NSMutableDictionary *getAccountData = [[NSMutableDictionary alloc] init];
        getAccountData[@"uuid"] = [[Device sharedInstance] uuid];
        getAccountData[@"username"] = [[Device sharedInstance] username];
        getAccountData[@"min_level"] = [[Device sharedInstance] minLevel];
        getAccountData[@"max_level"] = [[Device sharedInstance] maxLevel];
        getAccountData[@"type"] = @"get_account";
        syslog(@"[DEBUG] Sending get_account request: %@", getAccountData);
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:getAccountData
                  blocking:true
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
            
            // TODO: Check first_warning_timestamp]
            syslog(@"[INFO] Got account %@ from backend.", user);
            dispatch_semaphore_signal(sem);
        }];
    } else {
        syslog(@"[DEBUG] Already have an account.");
        dispatch_semaphore_signal(sem);
    }
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    syslog(@"[DEBUG] Got account, starting login sequence.");
    
    // Start login sequence and detection after we connect to backend.
    dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
    dispatch_async(queue, ^{
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:5];
        [UIC2 startLogin];
    });
}

+(void)startLogin
{
    // TODO: If not logged in for more than a minute before hitting main screen, restart
    __block bool isAgeVerification = false;
    __block bool isStartupLoggedOut = false;
    __block bool isStartup = false;
    __block bool isStartupLogo = false;
    __block bool isPassengerWarning = false;
    __block bool isWeather = false;
    __block bool isFailedLogin = false;
    __block bool isUnableAuth = false;
    __block bool isInvalidCredentials = false;
    __block bool isTos = false;
    __block bool isTosUpdate = false;
    __block bool isPrivacy = false;
    __block bool isPrivacyUpdate = false;
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
                              //betweenMin:[[ColorOffset alloc] init:0.0 green:0.75 blue:0.55]
                              //    andMax:[[ColorOffset alloc] init:1.0 green:0.90 blue: 0.70]];
                              betweenMin:[[ColorOffset alloc] init:0.55 green:0.75 blue:0.0]
                                  andMax:[[ColorOffset alloc] init:0.70 green:0.90 blue:1.0]];
        isPassengerWarning = [image rgbAtLocation:[[DeviceConfig sharedInstance] passenger]
                                       betweenMin:[[ColorOffset alloc] init:0.0 green:0.75 blue:0.55]
                                           andMax:[[ColorOffset alloc] init:1.0 green:0.90 blue:0.70]];
        isWeather = [image rgbAtLocation:[[DeviceConfig sharedInstance] weather]
                              betweenMin:[[ColorOffset alloc] init:0.23 green:0.35 blue:0.50]
                                  andMax:[[ColorOffset alloc] init:0.36 green:0.47 blue:0.65]];
        isFailedLogin = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginBanned]
                                  betweenMin:[[ColorOffset alloc] init:0.39 green:0.75 blue:0.55]
                                      andMax:[[ColorOffset alloc] init:0.49 green:0.90 blue:0.70]] &&
                        [image rgbAtLocation:[[DeviceConfig sharedInstance] loginBannedText]
                                  betweenMin:[[ColorOffset alloc] init:0.26 green:0.39 blue:0.40]
                                      andMax:[[ColorOffset alloc] init:0.36 green:0.49 blue:0.50]];
        isUnableAuth = [image rgbAtLocation:[[DeviceConfig sharedInstance] unableAuthButton]
                                 betweenMin:[[ColorOffset alloc] init:0.40 green:0.78 blue:0.56]
                                     andMax:[[ColorOffset alloc] init:0.50 green:0.88 blue:0.66]] &&
                       [image rgbAtLocation:[[DeviceConfig sharedInstance] unableAuthText]
                                 betweenMin:[[ColorOffset alloc] init:0.29 green:0.42 blue:0.43]
                                     andMax:[[ColorOffset alloc] init:0.39 green:0.52 blue:0.53]];
        isInvalidCredentials = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginFailed]
                                         betweenMin:[[ColorOffset alloc] init:0.40 green:0.78 blue:0.56]
                                             andMax:[[ColorOffset alloc] init:0.50 green:0.88 blue:0.66]] &&
                               [image rgbAtLocation:[[DeviceConfig sharedInstance] loginFailedText]
                                         betweenMin:[[ColorOffset alloc] init:0.23 green:0.37 blue:0.38]
                                             andMax:[[ColorOffset alloc] init:0.33 green:0.47 blue:0.48]];
        isTos = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginTerms]
                          betweenMin:[[ColorOffset alloc] init:0.00 green:0.75 blue:0.55]
                              andMax:[[ColorOffset alloc] init:1.00 green:0.90 blue:0.70]] &&
                [image rgbAtLocation:[[DeviceConfig sharedInstance] loginTermsText]
                          betweenMin:[[ColorOffset alloc] init:0.00 green:0.00 blue:0.00]
                              andMax:[[ColorOffset alloc] init:0.30 green:0.50 blue:0.50]];
        isTosUpdate = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginTerms2]
                                betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.57]
                                    andMax:[[ColorOffset alloc] init:0.48 green:0.87 blue:0.65]] &&
                      [image rgbAtLocation:[[DeviceConfig sharedInstance] loginTerms2Text]
                                betweenMin:[[ColorOffset alloc] init:0.11 green:0.35 blue:0.44]
                                    andMax:[[ColorOffset alloc] init:0.18 green:0.42 blue:0.51]];
        isPrivacy = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginPrivacy]
                              betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.60]
                                  andMax:[[ColorOffset alloc] init:0.50 green:0.85 blue:0.65]] &&
                    [image rgbAtLocation:[[DeviceConfig sharedInstance] loginPrivacyText]
                              betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.60]
                                  andMax:[[ColorOffset alloc] init:0.50 green:0.85 blue:0.65]];
        isPrivacyUpdate = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginPrivacyUpdate]
                                    betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.60]
                                        andMax:[[ColorOffset alloc] init:0.50 green:0.85 blue:0.65]] &&
                          [image rgbAtLocation:[[DeviceConfig sharedInstance] loginPrivacyUpdateText]
                                    betweenMin:[[ColorOffset alloc] init:0.22 green:0.36 blue:0.37]
                                        andMax:[[ColorOffset alloc] init:0.32 green:0.46 blue:0.47]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    bool loop = true;
    // TODO: Split into login phase/startup phase
    if (isAgeVerification) {
        syslog(@"[INFO] Age verification screen.");
        [UIC2 ageVerification];
        [UIC2 loginAccount];
    } else if (isStartupLoggedOut) {
        syslog(@"[INFO] App started in login screen.");
        [UIC2 loginAccount];
    } else if (isStartup) {
        syslog(@"[INFO] App still in startup logged in, waiting...");
        sleep(2);
    } else if (isFailedLogin) {
        syslog(@"[INFO] Found failed to login screen or banned screen.");
        DeviceCoordinate *switchAccount = [[DeviceConfig sharedInstance] loginBannedSwitchAccount];
        [JarvisTestCase touch:[switchAccount tapX] withY:[switchAccount tapY]];
        [[Device sharedInstance] setUsername:nil];
        sleep(1);
        [DeviceState logout];
        sleep(2);
    } else if (isStartupLogo) {
        syslog(@"[INFO] Startup logo found, waiting and trying again.");
        sleep(2); // TODO: 2 * DelayMultiplier
    } else if (isUnableAuth) {
        syslog(@"[INFO] Found unable to authenticate button.");
        DeviceCoordinate *unableAuth = [[DeviceConfig sharedInstance] unableAuthButton];
        [JarvisTestCase touch:[unableAuth tapX] withY:[unableAuth tapY]];
    } else if (isInvalidCredentials) {
        syslog(@"[INFO] Invalid credentials for %@", [[Device sharedInstance] username]);
        [[Device sharedInstance] setUsername:nil];
        NSMutableDictionary *invalidData = [[NSMutableDictionary alloc] init];
        invalidData[@"uuid"] = [[Device sharedInstance] uuid];
        invalidData[@"username"] = [[Device sharedInstance] username];
        invalidData[@"type"] = @"account_invalid_credentials";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:invalidData
                  blocking:true
                completion:^(NSDictionary *result) {}];
        sleep(2);
        // TODO: Set is logged in
    } else if (isTos) {
        syslog(@"[INFO] Accepting Terms of Service prompt.")
        DeviceCoordinate *tos = [[DeviceConfig sharedInstance] loginTerms];
        [JarvisTestCase touch:[tos tapX] withY:[tos tapY]];
        sleep(2); // TODO: 2 * DelayMultiplier
    } else if (isTosUpdate) {
        syslog(@"[INFO] Accepting updated Terms of Service prompt.");
        DeviceCoordinate *tos2 = [[DeviceConfig sharedInstance] loginTerms2];
        [JarvisTestCase touch:[tos2 tapX] withY:[tos2 tapY]];
        sleep(2);
    } else if (isPrivacy) {
        syslog(@"[INFO] Accepting Privacy Policy prompt");
        DeviceCoordinate *privacy = [[DeviceConfig sharedInstance] loginPrivacy];
        [JarvisTestCase touch:[privacy tapX] withY:[privacy tapY]];
        sleep(2);
    } else if (isPrivacyUpdate) {
        syslog(@"[INFO] Accepting updated Privacy Policy prompt.");
        DeviceCoordinate *privacyUpdate = [[DeviceConfig sharedInstance] loginPrivacyUpdate];
        [JarvisTestCase touch:[privacyUpdate tapX] withY:[privacyUpdate tapY]];
        sleep(2);
    } else if ([self isStartupPrompt]) {
        syslog(@"[INFO] Found startup prompt.");
        sleep(2);
    } else if (isPassengerWarning) {
        syslog(@"[INFO] Found passenger warning.");
        DeviceCoordinate *passenger = [[DeviceConfig sharedInstance] passenger];
        [JarvisTestCase touch:[passenger tapX] withY:[passenger tapY]];
        sleep(2);
        //DeviceCoordinate *closeNews = [[DeviceConfig sharedInstance] closeMenu]; // closeNews / closeMenu
        //[JarvisTestCase touch:[closeNews tapX] withY:[closeNews tapY]];
        //sleep(2);
        if (!_dataStarted) {
            syslog(@"[INFO] Starting job handler.");
            _dataStarted = true;
            [self getJobHandler];
        }
    } else if (isWeather) {
        syslog(@"[INFO] Found weather alert.");
        DeviceCoordinate *closeWeather1 = [[DeviceConfig sharedInstance] closeWeather1];
        [JarvisTestCase touch:[closeWeather1 tapX] withY:[closeWeather1 tapY]];
        sleep(2);
        DeviceCoordinate *closeWeather2 = [[DeviceConfig sharedInstance] closeWeather2];
        [JarvisTestCase touch:[closeWeather2 tapX] withY:[closeWeather2 tapX]];
        sleep(2);
    } else if ([self isMainScreen]) {
        syslog(@"[INFO] Found main screen.");
        sleep(2);
        if (!_dataStarted) {
            syslog(@"[INFO] Starting job handler.");
            _dataStarted = true;
            [self getJobHandler];
        }
    } else if ([self isTutorial]) {
        syslog(@"[INFO] Found tutorial screen.");
        [self doTutorialSelection];
    } else if ([self isBanned]) {
        syslog(@"[INFO] Found banned screen. Restarting...");
        [[Device sharedInstance] setUsername:nil];
        NSMutableDictionary *bannedData = [[NSMutableDictionary alloc] init];
        bannedData[@"uuid"] = [[Device sharedInstance] uuid];
        bannedData[@"username"] = [[Device sharedInstance] username];
        bannedData[@"type"] = @"account_banned";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:bannedData
                  blocking:true
                completion:^(NSDictionary *result) {}];
        sleep(2);
        loop = false;
        [DeviceState restart];
    } else {
        //syslog(@"[WARN] Nothing found");
        sleep(5);
        loop = true;
    }

    if (loop) {
        [self startLogin];
    }
}

// TODO: Move to DeviceState
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
    [Jarvis__ typeUsername];
    sleep(sleepDelay);
    
    // Click Password text field
    DeviceCoordinate *loginPasswordTextfield = [[DeviceConfig sharedInstance] loginPasswordTextfield];
    syslog(@"[DEBUG] Tappng password text field %@", loginPasswordTextfield);
    [JarvisTestCase touch:[loginPasswordTextfield tapX]
                    withY:[loginPasswordTextfield tapY]];
    sleep(sleepDelay);
    
    // Type account password
    [Jarvis__ typePassword];
    sleep(sleepDelay);
    
    // Click Config login button
    DeviceCoordinate *loginConfirm = [[DeviceConfig sharedInstance] loginConfirm];
    syslog(@"[DEBUG] Tapping confirm login %@", loginConfirm);
    [JarvisTestCase touch:[loginConfirm tapX]
                    withY:[loginConfirm tapY]];
    sleep(sleepDelay);
}

+(void)doTutorialSelection
{
    syslog(@"[INFO] [TUT] Tapping 9 times passed Professor Willow screen.");
    for (int i = 0; i < 9; i++) {
        [JarvisTestCase touch:160 withY:160]; // TODO: Add or use DeviceConfig
        sleep(2);
    }
    sleep(1);
    syslog(@"[INFO] [TUT] Selecting female gender.");
    DeviceCoordinate *genderFemale = [[DeviceConfig sharedInstance] tutorialGenderFemale];
    [JarvisTestCase touch:[genderFemale tapX] withY:[genderFemale tapY]];
    sleep(1);
    syslog(@"[INFO] [TUT] Tapping next button 3 times.");
    DeviceCoordinate *tutorialStyleConfirm = [[DeviceConfig sharedInstance] tutorialStyleConfirm];
    DeviceCoordinate *tutorialNext = [[DeviceConfig sharedInstance] tutorialNext];
    // If not style confirmation button, keep clicking next.
    while (![self isAtPixel:tutorialStyleConfirm
                 betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.47 green:0.86 blue:0.63]]) {
        [JarvisTestCase touch:[tutorialNext tapX] withY:[tutorialNext tapY]];
        sleep(2);
    }
    sleep(2);
    syslog(@"[INFO] [TUT] Confirming style selection.");
    [JarvisTestCase touch:[tutorialStyleConfirm tapX] withY:[tutorialStyleConfirm tapY]];
    sleep(2);

    // TODO: Block Until Clicked/pixel check method
    syslog(@"[INFO] [TUT] Willow prompt, tapping 2 times.");
    for (int i = 0; i < 3; i++) {
        [JarvisTestCase touch:160 withY:160]; // TODO: Add or use DeviceConfig
        sleep(2);
    }
    sleep(3); // TODO: If 5S/6, wait a little longer
    int failed = 0;
    int maxFails = 5;
    while (![self findAndClickPokemon]) {
        syslog(@"[WARN] [TUT] Failed to find Pokemon, rotating...");
        DeviceCoordinate *ageStart = [[DeviceConfig sharedInstance] ageVerificationDragStart];
        DeviceCoordinate *ageEnd = [[DeviceConfig sharedInstance] ageVerificationDragEnd];
        [JarvisTestCase drag:ageStart toPoint:ageEnd];
        sleep(5);
        failed++;
        if (failed >= maxFails) {
            break;
        }
    }
    if (failed >= maxFails) {
        syslog(@"[ERROR] [TUT] Failed to find and click Pokemon to catch...");
        return;
    }
    sleep(4);
    // Check for camera permissions prompt.
    syslog(@"[DEBUG] [TUT] Checking for AR(+) camera permissions prompt...");
    bool isArPrompt = [self isArPlusPrompt];
    if (isArPrompt) {
        syslog(@"[INFO] [TUT] Found AR(+) prompt, clicking.");
        DeviceCoordinate *startupOldCoordinate = [[DeviceConfig sharedInstance] startupOldOkButton];
        [JarvisTestCase touch:[startupOldCoordinate tapX] withY:[startupOldCoordinate tapY]];
        sleep(2);
    }
    sleep(3);
    // If we haven't hit the post capture prompt yet, keep attempting to throw pokeballs.
    //0.611765 0.839216 0.466667 1
    //0.611765 0.839216 0.462745 1
    while (![self isAtPixel:[[DeviceConfig sharedInstance] tutorialCatchConfirm] // passenger / 0.988235 1 0.988235 1
                 betweenMin:[[ColorOffset alloc] init:0.60 green:0.82 blue:0.45] // catchConfirm / 0.611765 0.839216 0.466667 1
                     andMax:[[ColorOffset alloc] init:0.63 green:0.85 blue:0.48]] &&
           ![self isAtPixel:[[DeviceConfig sharedInstance] tutorialCatchConfirm]
                 betweenMin:[[ColorOffset alloc] init:0.45 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.48 green:0.85 blue:0.63]]) {
        syslog(@"[INFO] [TUT] Attempting to throw Pokeball.");
        DeviceCoordinate *ageStart = [[DeviceConfig sharedInstance] ageVerificationDragStart];
        DeviceCoordinate *ageEnd = [[DeviceConfig sharedInstance] ageVerificationDragEnd];
        [JarvisTestCase drag:ageStart toPoint:ageEnd];
        syslog(@"[INFO] [TUT] Pokeball thrown.");
        sleep(10);
    }
    syslog(@"[INFO] [TUT] Pokemon caught!");
    sleep(2);
    //310x755 - 0.611765 0.839216 0.466667
    syslog(@"[INFO] [TUT] Tapping OK after Pokemon caught button and waiting 10 seconds.");
    DeviceCoordinate *catchConfirm = [[DeviceConfig sharedInstance] tutorialCatchConfirm];
    [JarvisTestCase touch:[catchConfirm tapX] withY:[catchConfirm tapY]];
    sleep(10); // TODO: Wait for pokedex animation to finish. Wait longer on 5S/6 devices.
    syslog(@"[INFO] [TUT] Closing Pokemon screen.");
    // TODO: Pixel check close button
    DeviceCoordinate *closeButton = [[DeviceConfig sharedInstance] closeMenu];
    [JarvisTestCase touch:[closeButton tapX] withY:[closeButton tapY]];
    sleep(3);
    syslog(@"[INFO] [TUT] Willow prompt, tapping 2 times.");
    [JarvisTestCase touch:160 withY:160]; // TODO: Add or use DeviceConfig
    sleep(3);
    [JarvisTestCase touch:160 withY:160]; // TODO: Add or use DeviceConfig
    sleep(5);
    NSString *username = [[Device sharedInstance] username];
    NSString *usernameReturn = [NSString stringWithFormat:@"%@\n", username];
    syslog(@"[INFO] [TUT] Typing in nickname %@", username)
    [JarvisTestCase type:usernameReturn];
    sleep(1);
    // TODO: While not confirm button keep trying to enter random username and click OK button on fail.
    // Click OK button.
    if ([self isPassengerWarning]) {
        syslog(@"[INFO] [TUT] Clicking OK username button.");
        DeviceCoordinate *passenger = [[DeviceConfig sharedInstance] passenger];
        [JarvisTestCase touch:[passenger tapX] withY:[passenger tapY]];
    }
    sleep(2);
    // Confirm username.
    syslog(@"[INFO] [TUT] Confirming username.");
    DeviceCoordinate *confirm = [[DeviceConfig sharedInstance] tutorialStyleConfirm];
    [JarvisTestCase touch:[confirm tapX] withY:[confirm tapY]];
    sleep(2);
    // x 327-765 0.615686 0.835294 0.439216 1
    syslog(@"[INFO] [TUT] Clicking away Professor Willow screens.");
    DeviceCoordinate *pokestopConfirm = [[DeviceConfig sharedInstance] tutorialPokestopConfirm];
    while (![self isAtPixel:pokestopConfirm
                 betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.46 green:0.85 blue:0.63]]) {
        [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
        sleep(2);
    }
    sleep(3);
    // Click Pokestop button.
    syslog(@"[INFO] [TUT] Clicking away spin Pokestop prompt.");
    [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
    sleep(2);
    syslog(@"[INFO] [TUT] Tutorial done!");
    NSMutableDictionary *tutData = [[NSMutableDictionary alloc] init];
    tutData[@"uuid"] = [[Device sharedInstance] uuid];
    tutData[@"username"] = [[Device sharedInstance] username];
    tutData[@"type"] = @"tutorial_done";
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:tutData
              blocking:true
            completion:^(NSDictionary *result) {}];
}


#pragma mark Pixel Check Methods
// TODO: Make extension class

+(BOOL)isAtPixel:(DeviceCoordinate *)coordinate betweenMin:(ColorOffset *)min andMax:(ColorOffset *)max
{
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:coordinate
                           betweenMin:min
                               andMax:max
        ];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isStartupPrompt
{
    //syslog(@"[DEBUG] Starting startup prompt check.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startupNewCautionSign]
                      betweenMin:[[ColorOffset alloc] init:1.00 green:0.97 blue:0.60]
                          andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:0.65]] &&
            [image rgbAtLocation:[[DeviceConfig sharedInstance] startupNewButton]
                      betweenMin:[[ColorOffset alloc] init:0.28 green:0.79 blue:0.62]
                          andMax:[[ColorOffset alloc] init:0.33 green:0.85 blue:0.68]]) {
            syslog(@"[DEBUG] Clearing caution sign new startup prompt.");
            DeviceCoordinate *startupNewCoordinate = [[DeviceConfig sharedInstance] startupNewButton];
            [JarvisTestCase touch:[startupNewCoordinate tapX] withY:[startupNewCoordinate tapY]];
            result = true;
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldOkButton]
                             betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                                 andMax:[[ColorOffset alloc] init:0.47 green:0.86 blue:0.63]] &&
                   [image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldCornerTest]
                             betweenMin:[[ColorOffset alloc] init:0.15 green:0.41 blue:0.45]
                                 andMax:[[ColorOffset alloc] init:0.19 green:0.46 blue:0.49]]) {
            syslog(@"[DEBUG] Clearing 2 line long old style startup prompt.");
            DeviceCoordinate *startupOldCoordinate = [[DeviceConfig sharedInstance] startupOldOkButton];
            [JarvisTestCase touch:[startupOldCoordinate tapX] withY:[startupOldCoordinate tapY]];
            result = true;
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldOkButton]
                             betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                                 andMax:[[ColorOffset alloc] init:0.47 green:0.86 blue:0.63]] &&
                   [image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldCornerTest]
                             betweenMin:[[ColorOffset alloc] init:0.99 green:0.99 blue:0.99]
                                 andMax:[[ColorOffset alloc] init:1.01 green:1.01 blue:1.01]]) {
            syslog(@"[DEBUG] Clearing 3 line long old school startup prompt.");
            DeviceCoordinate *startupOldCoordinate = [[DeviceConfig sharedInstance] startupOldOkButton];
            [JarvisTestCase touch:[startupOldCoordinate tapX] withY:[startupOldCoordinate tapY]];
            result = true;
        }
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isMainScreen
{
    //syslog(@"[DEBUG] Starting main screen check.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] closeMenu]
                           betweenMin:[[ColorOffset alloc] init:0.98 green:0.98 blue:0.98]
                               andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:1.00]] &&//|| //&&
                ([image rgbAtLocation:[[DeviceConfig sharedInstance] mainScreenPokeballRed]
                           betweenMin:[[ColorOffset alloc] init:0.80 green:0.10 blue:0.17]
                               andMax:[[ColorOffset alloc] init:1.00 green:0.34 blue:0.37]]);/* ||
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] mainScreenPokeballRed]
                           betweenMin:[[ColorOffset alloc] init:0.75 green:0.72 blue:0.12]
                               andMax:[[ColorOffset alloc] init:0.95 green:0.84 blue:0.33]
                 ]);*/
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isTutorial
{
    //syslog(@"[DEBUG] Starting tutorial screen check.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] compareTutorialL]
                           betweenMin:[[ColorOffset alloc] init:0.3 green:0.5 blue:0.6]
                               andMax:[[ColorOffset alloc] init:0.4 green:0.6 blue:0.7]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] compareWarningR]
                           betweenMin:[[ColorOffset alloc] init:0.3 green:0.5 blue:0.6]
                               andMax:[[ColorOffset alloc] init:0.4 green:0.6 blue:0.7]
                 ];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isPassengerWarning
{
    //syslog(@"[DEBUG] Checking for Passenger warning.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] passenger]
                           betweenMin:[[ColorOffset alloc] init:0.0 green:0.75 blue:0.55]
                               andMax:[[ColorOffset alloc] init:1.0 green:0.90 blue:0.70]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isArPlusPrompt
{
    //syslog(@"[DEBUG] Checking for AR(+) prompt.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldOkButton]
                           betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                               andMax:[[ColorOffset alloc] init:0.47 green:0.86 blue:0.63]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldCornerTest]
                           betweenMin:[[ColorOffset alloc] init:0.99 green:0.99 blue:0.99]
                               andMax:[[ColorOffset alloc] init:1.01 green:1.01 blue:1.01]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isBanned
{
    return [self isAtPixel:[[DeviceConfig sharedInstance] loginBannedBackground]
                betweenMin:[[ColorOffset alloc] init:0.00 green:0.20 blue:0.30]
                    andMax:[[ColorOffset alloc] init:0.05 green:0.30 blue:0.40]
    ];
}

+(BOOL)findAndClickPokemon
{
    syslog(@"[INFO] [TUT] Starting to look for Pokemon to click.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        size_t width = CGImageGetWidth([image CGImage]);
        size_t height = CGImageGetHeight([image CGImage]);
        syslog(@"[DEBUG] [TUT] Scanning Pokemon...");
        // TODO: Check feet coords 324 818
        int feetX = 324;
        int feetY = 818;
        UIColor *feetColor = [image getPixelColor:feetX withY:feetY]; // TODO: Make DeviceCoordinate
        CGFloat red = 0;
        CGFloat green = 0;
        CGFloat blue = 0;
        CGFloat alpha = 0;
        [feetColor getRed:&red green:&green blue:&blue alpha:&alpha];
        syslog(@"[DEBUG] [TUT] Checking if Pokemon at feet.");
        if (red > 0.9 &&
            green > 0.6 && green < 0.8 && //0.7
            blue > 0.3 && blue < 0.5) { //0.4
            double locX = lround(feetX) * 0.5; // TODO: DelayMultiplier
            double locY = lround(feetY) * 0.5;
            NSLog(@"[Jarvis] [INFO] [TUT] Pokemon found at feet! Attempting to click at %f, %f", locX, locY);
            [JarvisTestCase touch:locX withY:locY];
            result = true;
            dispatch_semaphore_signal(sem);
        }
        for (int x = 8; x < width / 10; x++) {
            for (int y = 40; y < height / 10; y++) {
                int realX = x * 10;
                int realY = y * 10;
                //NSLog(@"[Jarvis] [DEBUG] [TUT] findAndClickPokemon: Comparing at %d, %d", realX, realY);
                UIColor *color = [image getPixelColor:realX withY:realY];
                CGFloat red = 0;
                CGFloat green = 0;
                CGFloat blue = 0;
                CGFloat alpha = 0;
                [color getRed:&red green:&green blue:&blue alpha:&alpha];
                //NSLog(@"[Jarvis] [DEBUG] [TUT] Pixel: red=%f green=%f blue=%f alpha=%f", red, green, blue, alpha);
                if (red > 0.9 &&
                    green > 0.6 && green < 0.8 && //0.7
                    blue > 0.3 && blue < 0.5) { //0.4
                    double locX = lround(realX) * 0.5; // TODO: DelayMultiplier
                    double locY = lround(realY) * 0.5;
                    syslog(@"[INFO] [TUT] Pokemon found! Attempting to click at %f, %f", locX, locY);
                    [JarvisTestCase touch:locX withY:locY];
                    result = true;
                    dispatch_semaphore_signal(sem);
                    break;
                }
                sleep(0.5);
            }
        }
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

@end
