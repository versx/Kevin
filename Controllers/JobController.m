//
//  JobController.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "JobController.h"

@implementation JobController

static dispatch_queue_t _getJobQueue;

+(JobController *)sharedInstance
{
    static JobController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[JobController alloc] init];
    });
    return sharedInstance;
}


-(id)init
{
    syslog(@"[INFO] init");
    if ((self = [super init])) {
        _getJobQueue = dispatch_queue_create("getjob_queue", NULL);
    }
    
    return self;
}

-(void)initialize
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
        
        [DeviceState checkWarning:data[@"first_warning_timestamp"]];
        
        syslog(@"[INFO] Connected to backend successfully!");
        [[Device sharedInstance] setShouldExit:false];
    }];
    
    if ([[Device sharedInstance] shouldExit]) {
        [[Device sharedInstance] setShouldExit:false];
        [NSThread sleepForTimeInterval:5];
        [DeviceState restart];
    }
}

-(void)getAccount
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
                syslog(@"[DEBUG] startupLocation: %@", startupLocation);
                [DeviceState checkWarning:data[@"first_warning_timestamp"]];
            } else {
                syslog(@"[WARN] Failed to get account and not logged in.");
                [[Device sharedInstance] setMinLevel:@0];
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

-(void)getJobs
{
    [[DeviceState sharedInstance] setIsStartup:false];

    dispatch_async(_getJobQueue, ^{
        bool hasWarning = false;
        [[DeviceState sharedInstance] setFailedGetJobCount:@0];
        [[DeviceState sharedInstance] setFailedCount:@0];
        [[DeviceState sharedInstance] setEmptyGmoCount:@0];
        [[DeviceState sharedInstance] setNoQuestCount:@0];
        //_noEncounterCount = 0;

        // Grab an account from the backend controller.
        [self getAccount];
        
        syslog(@"[INFO] Starting job handler.");
        // Start grabbing jobs from the backend controller.
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
                        dispatch_semaphore_signal(sem);
                        return;
                    } else {
                        syslog(@"[ERROR] Failed to get a job.");
                        dispatch_semaphore_signal(sem);
                        return;
                    }
                } else if ([[Settings sharedInstance] enableAccountManager]) {
                    data = result[@"data"];
                    if (data != nil) {
                        NSNumber *currentLevel = [[Device sharedInstance] level];
                        NSNumber *minLevel = [data objectForKey:@"min_level"];
                        NSNumber *maxLevel = [data objectForKey:@"max_level"];
                        if (minLevel && maxLevel) {
                            [[Device sharedInstance] setMinLevel:minLevel];
                            [[Device sharedInstance] setMaxLevel:maxLevel];
                            syslog(@"[DEBUG] Current level %@ (Min: %@, Max: %@)", currentLevel, minLevel, maxLevel);
                            if ([currentLevel intValue] != 0 &&
                                ([currentLevel intValue] < [minLevel intValue] ||
                                 [currentLevel intValue] > [maxLevel intValue])) {
                                syslog(@"[WARN] Account is outside min/max level range. Logging out!");
                                //self.lock.lock();
                                CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                                [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                                [DeviceState logout];
                                //self.lock.unlock();
                            }
                        }
                    }
                }
                
                [[DeviceState sharedInstance] setFailedGetJobCount:@0];
                if (data == nil) {
                    syslog(@"[WARN] No job left (Result: %@)", result);
                    [NSThread sleepForTimeInterval:5];
                    dispatch_semaphore_signal(sem);
                    return;
                }

                // Parse job based on type.
                NSString *action = data[@"action"];
                [[DeviceState sharedInstance] setLastAction:action];
                if ([action isEqualToString:@"scan_pokemon"]) {
                    syslog(@"[DEBUG] [STATUS] Pokemon");
                    [self handlePokemonJob:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"scan_raid"]) {
                    syslog(@"[DEBUG] [STATUS] Raid");
                    [self handleRaidJob:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"scan_quest"]) {
                    syslog(@"[DEBUG] [STATUS] Quest/Leveling");
                    [self handleQuestJob:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"switch_account"]) {
                    syslog(@"[DEBUG] [STATUS] Switching Accounts");
                    [self handleSwitchAccount:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"leveling"]) {
                    syslog(@"[DEBUG] [STATUS] Leveling");
                    [self handleLeveling:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"scan_iv"]) {
                    syslog(@"[DEBUG] [STATUS] IV");
                    [self handleIVJob:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"gather_token"]) {
                    syslog(@"[DEBUG] [STATUS] Token");
                    [self handleGatherToken:action withData:data hasWarning:hasWarning];
                } else {
                    syslog(@"[WARN] Unknown action received: %@", action);
                }
                
                dispatch_semaphore_signal(sem);
                
                NSNumber *emptyGmoCount = [[DeviceState sharedInstance] emptyGmoCount];
                NSNumber *maxEmptyGMO = [[Settings sharedInstance] maxEmptyGMO];
                if ([emptyGmoCount intValue] >= [maxEmptyGMO intValue]) {
                    syslog(@"[WARN] Got Empty GMO %@ times in a row. Restarting...", emptyGmoCount);
                    [DeviceState restart];
                }
                
                NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
                NSNumber *maxFailedCount = [[Settings sharedInstance] maxFailedCount];
                if ([failedCount intValue] >= [maxFailedCount intValue]) {
                    syslog(@"[ERROR] Failed %@ times in a row. Restarting...", failedCount);
                    [DeviceState restart];
                }
                sleep(2);
            }];
            
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            sleep(1);
        }
    });
}


#pragma mark Job Handlers

-(void)handlePokemonJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    if (hasWarning && [[Settings sharedInstance] enableAccountManager]) {
        syslog(@"[WARN] Account has a warning and tried to scan for Pokemon. Logging out!");
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = data[@"lat"];
    NSNumber *lon = data[@"lon"];
    syslog(@"[INFO] Scanning for Pokemon at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    [[DeviceState sharedInstance] setWaitRequiresPokemon:true];
    [[DeviceState sharedInstance] setPokemonEncounterId:nil];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]]];
    [[DeviceState sharedInstance] setWaitForData:true];
    //self.lock.unlock();
    syslog(@"[INFO] Scanning prepared");
    
    BOOL locked = true;
    while (locked) {
        [NSThread sleepForTimeInterval:1];
        //self.lock.lock();
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince >= 30) { // TODO: Make constant
            locked = false;
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            syslog(@"[WARN] Pokemon loading timed out.");
            NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
            failedData[@"uuid"] = [[Device sharedInstance] uuid];
            failedData[@"username"] = [[Device sharedInstance] username];
            failedData[@"action"] = action;
            failedData[@"lat"] = lat;
            failedData[@"lon"] = lon;
            failedData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                          dict:failedData
                      blocking:true
                    completion:^(NSDictionary *result) {}
            ];
        } else {
            locked = [[DeviceState sharedInstance] waitForData];
            if (!locked) {
                [[DeviceState sharedInstance] setFailedCount:@0];
                syslog(@"[INFO] Pokemon loaded after %f seconds.", timeIntervalSince);
            }
        }
    }
}

-(void)handleRaidJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
    NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:firstWarningDate];
    NSNumber *maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
    if (hasWarning &&
        firstWarningDate != nil &&
        timeSince >= [maxWarningTimeRaid intValue] &&
        [[Settings sharedInstance] enableAccountManager]) {
        syslog(@"[WARN] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = data[@"lat"] ?: 0;
    NSNumber *lon = data[@"lon"] ?: 0;
    syslog(@"[INFO] Scanning for Raid at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setWaitForData:true];
    //self.lock.unlock();
    syslog(@"[INFO] Scanning prepared.");
    
    BOOL locked = true;
    NSNumber *raidMaxTime = [[Settings sharedInstance] raidMaxTime];
    while (locked) {
        //self.lock.lock();
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince >= [raidMaxTime intValue]) {
            locked = false;
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            syslog(@"[WARN] Raids loading timed out.");
            NSMutableDictionary *raidData = [[NSMutableDictionary alloc] init];
            raidData[@"uuid"] = [[Device sharedInstance] uuid];
            raidData[@"action"] = action;
            raidData[@"lat"] = lat;
            raidData[@"lon"] = lon;
            raidData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                          dict:raidData
                      blocking:true
                    completion:^(NSDictionary *result) {}
            ];
        } else {
            locked = [[DeviceState sharedInstance] waitForData];
            if (!locked) {
                [[DeviceState sharedInstance] setFailedCount:0];
                syslog(@"[INFO] Raids loaded after %f", timeIntervalSince);
            }
        }
        //self.lock.unlock();
    }
}

-(void)handleQuestJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    [[DeviceState sharedInstance] setDelayQuest:true];
    NSNumber *lat = data[@"lat"];
    NSNumber *lon = data[@"lon"];
    NSNumber *delay = data[@"delay"];
    syslog(@"[INFO] Scanning for Quest at %@ %@ in %@ seconds", lat, lon, delay);
    NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
    
    if (hasWarning && firstWarningDate != nil && [NSDate date]) {
        syslog(@"[WARN] Account has a warning and is over maxWarningTimeRaid. Logging out!");
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        //self.lock.unlock();
        [DeviceState logout];
    }
    
    if ([[Settings sharedInstance] deployEggs] &&
        [[DeviceState sharedInstance] eggStart] < [NSDate date] &&
        [[[Device sharedInstance] level] intValue] >= 9 &&
        [[[Device sharedInstance] level] intValue] < 30) {
        /* TODO: Egg Deploy
        NSNumber *i = @(arc4random_uniform(60));
        [NSThread sleepForTimeInterval:2];
        if ([Jarvis__ getToMainScreen]) {
            syslog(@"[INFO] Deploying an egg");
            if ([Jarvis__ eggDeploy]) {
                // If an egg was found, set the timer to 31 minutes.
                //NSDate *eggStart = [[NSDate date] initWithTimeInterval:(1860 + [i intValue]) sinceDate:[NSDate date]];
                NSDate *eggStart = [NSDate dateWithTimeInterval:(1860 + [i intValue]) sinceDate:[NSDate date]];
                [[DeviceState sharedInstance] setEggStart:eggStart];
            } else {
                // If no egg was used, set the timer to 16 minutes so it rechecks.
                // Useful if you get more eggs from leveling up.
                NSDate *eggStart = [NSDate dateWithTimeInterval:(960 + [i intValue]) sinceDate:[NSDate date]];
                [[DeviceState sharedInstance] setEggStart:eggStart];
            }
            syslog(@"[INFO] Egg timer set to %@ UTC for a recheck.", [[DeviceState sharedInstance] eggStart]);
        } else {
            
            NSDate *eggStart = [NSDate dateWithTimeInterval:(960 + [i intValue]) sinceDate:[NSDate date]];
            [[DeviceState sharedInstance] setEggStart:eggStart];
        }
         */
        syslog(@"[INFO] Egg timer set to %@ UTC for a recheck.", [[DeviceState sharedInstance] eggStart]);
    }
    
    if (delay >= [[Settings sharedInstance] minDelayLogout] &&
                 [[Settings sharedInstance] enableAccountManager]) {
        syslog(@"[WARN] Switching account. Delay too large.");
        NSMutableDictionary *questData = [[NSMutableDictionary alloc] init];
        questData[@"uuid"] = [[Device sharedInstance] uuid];
        questData[@"action"] = action;
        questData[@"lat"] = lat;
        questData[@"lon"] = lon;
        questData[@"type"] = @"job_failed";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:questData
                  blocking:true
                completion:^(NSDictionary *result) {}
        ];
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        //self.lock.unlock();
        [DeviceState logout];
    }
    
    [[DeviceState sharedInstance] setNewCreated:false];
    
    //self.lock.lock();
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
    [[DeviceState sharedInstance] setPokemonEncounterId:nil];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setWaitForData:true];
    [[DeviceState sharedInstance] setGotQuest:false];
    //self.lock.unlock();
    syslog(@"[INFO] Scanning prepared");
    
    NSDate *start = [NSDate date];
    BOOL success = false;
    BOOL locked = true;
    BOOL found = false;
    while (locked) {
        sleep(2); // TODO: DelayMultiplier
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince <= 5) {
            continue;
        }
        if (!found && (timeIntervalSince <= [delay doubleValue])) {
            NSNumber *left = @([delay doubleValue] - timeIntervalSince);
            //NSNumber *delayDouble = [NSNumber numberWithDouble:[delay doubleValue]];
            //NSDate *end = [[NSDate date] initWithTimeIntervalSince1970:[delayDouble doubleValue]];
            syslog(@"[INFO] Delaying by %@ seconds.", left);

            while (!found && ([[NSDate date] timeIntervalSinceDate:start]/*timeIntervalSince*/ <= [delay doubleValue])) {
                //self.lock.lock();
                locked = [[DeviceState sharedInstance] gotQuestEarly];
                //self.lock.unlock();
                if (locked) {
                    sleep(1);
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
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            syslog(@"[WARN] Pokestop loading timed out.");
            NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
            failedData[@"uuid"] = [[Device sharedInstance] uuid];
            failedData[@"action"] = action;
            failedData[@"lat"] = lat;
            failedData[@"lon"] = lon;
            failedData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                          dict:failedData
                      blocking:true
                    completion:^(NSDictionary *result) {}
            ];
        } else {
            locked = [[DeviceState sharedInstance] waitForData];
            if (!locked) {
                [[DeviceState sharedInstance] setDelayQuest:true];
                success = true;
                [[DeviceState sharedInstance] setFailedCount:0];
                syslog(@"[INFO] Pokestop loaded after %f", timeIntervalSince);
            }
        }
        //self.lock.unlock();
    }

    if ([action isEqualToString:@"scan_quest"]) {
        //self.lock.lock();
        if ([[DeviceState sharedInstance] gotQuest]) {
            [[DeviceState sharedInstance] setNoQuestCount:0];
        } else {
            NSNumber *noQuestCount = [[DeviceState sharedInstance] noQuestCount];
            [[DeviceState sharedInstance] setNoQuestCount:[Utils incrementInt:noQuestCount]];
        }
        [[DeviceState sharedInstance] setGotQuest:false];

        if ([[DeviceState sharedInstance] noQuestCount] >= [[Settings sharedInstance] maxNoQuestCount]) {
            //self.lock.unlock();
            syslog(@"[WARN] Stuck somewhere. Restarting...");
            [DeviceState logout];
        }
        
        //self.lock.unlock();
        if (success) {
            int attempts = 0;
            while (attempts < 5) {
                attempts++;
                //self.lock.lock();
                BOOL gotQuest = [[DeviceState sharedInstance] gotQuest];
                syslog(@"[INFO] Got quest data: %@", gotQuest ? @"Yes" : @"No");
                if (!gotQuest) {
                    syslog(@"[DEBUG] UltraQuests pokestop re-attempt: %d", attempts);
                    //self.lock.unlock();
                    sleep(2);
                } else {
                    //self.lock.unlock();
                    break;
                }
            }
        }
    }
}

-(void)handleLeveling:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    [[DeviceState sharedInstance] setDelayQuest:false];
    //degreePerMeter = 83267.0991559005
    NSNumber *lat = data[@"lat"] ?: 0;
    NSNumber *lon = data[@"lon"] ?: 0;
    NSNumber *delay = data[@"delay"] ?: @0.0;
    NSString *fortType = data[@"fort_type"] ?: @"P";
    NSString *targetFortId = data[@"fort_id"] ?: @"";
    [[DeviceState sharedInstance] setTargetFortId:targetFortId];
    syslog(@"[DEBUG] [RES1] Location: %@ %@ Delay: %@ FortType: %@ FortId: %@", lat, lon, delay, fortType, targetFortId);
    
    if (![[DeviceState sharedInstance] isQuestInit]) {
        [[DeviceState sharedInstance] setIsQuestInit:true];
        delay = @30.0;
    } else {
        CLLocation *newLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        CLLocation *lastLocation = [[DeviceState sharedInstance] lastQuestLocation];
        NSNumber *questDistance = [NSNumber numberWithDouble:[newLocation distanceFromLocation:lastLocation]];
        
        // Check if previous spin had quest data
        //self.lock.lock();
        if ([[DeviceState sharedInstance] gotItems]) {
            [[DeviceState sharedInstance] setNoItemsCount:0];
        } else {
            NSNumber *noItemsCount = [[DeviceState sharedInstance] noItemsCount];
            [[DeviceState sharedInstance] setNoItemsCount:[Utils incrementInt:noItemsCount]];
        }
        [[DeviceState sharedInstance] setGotItems:false];
        //self.lock.unlock();
        
        NSNumber *noItemsCount = [[DeviceState sharedInstance] noItemsCount];
        if ([noItemsCount intValue] >= 200) {
            [[DeviceState sharedInstance] setIsQuestInit:false];
            [[DeviceState sharedInstance] setNoItemsCount:0];
            syslog(@"[WARN] Stuck somewhere. Restarting accounts...");
            [DeviceState restart];
            [[Device sharedInstance] setShouldExit:true];
            return;
        }
        
        [[DeviceState sharedInstance] setSkipSpin:false];
        syslog(@"[DEBUG] Quest Distance: %@", questDistance);
        if ([questDistance intValue] <= 5.0) {
            delay = @0.0;
            [[DeviceState sharedInstance] setSkipSpin:true];
            syslog(@"[DEBUG] Quest Distance: %@m < 30.0m Already spun this pokestop. Go to next pokestop.", questDistance);
            [[DeviceState sharedInstance] setGotItems:true];
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
    
    if (![[DeviceState sharedInstance] skipSpin]) {
        syslog(@"[INFO] Spinning fort at %@ %@ in %@ seconds", lat, lon, delay);
        CLLocation *lastQuestLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        [[DeviceState sharedInstance] setLastQuestLocation:lastQuestLocation];
        NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
        NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:firstWarningDate];
        NSNumber *maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
        if (hasWarning &&
            firstWarningDate != nil &&
            timeSince >= [maxWarningTimeRaid intValue] &&
            [[Settings sharedInstance] enableAccountManager]) {
            syslog(@"[WARN] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
            //self.lock.lock();
            CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
            [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
            [[Device sharedInstance] setUsername:nil];
            [[Device sharedInstance] setIsLoggedIn:false];
            [[DeviceState sharedInstance] setIsQuestInit:false];
            //self.lock.unlock();
            [[NSUserDefaults standardUserDefaults] synchronize];
            [DeviceState logout];
        }
        
        [[DeviceState sharedInstance] setNewCreated:false];
        //self.lock.lock();
        [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]]];
        [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
        [[DeviceState sharedInstance] setPokemonEncounterId:nil];
        //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance] ?: @250.0;
        [[DeviceState sharedInstance] setWaitForData:false];
        //self.lock.unlock();
        syslog(@"[INFO] Scanning prepared");
        
        NSDate *start = [NSDate date];
        NSNumber *delayTemp = delay;
        bool success = false;
        bool locked = true;
        while (locked) {
            sleep(1);
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
            if (timeIntervalSince >= [delayTemp intValue]) {
                NSNumber *left = @([delayTemp intValue] - timeIntervalSince);
                syslog(@"[DEBUG] Delaying by %@", left);
                sleep(MIN(10, [left intValue]));
                continue;
            }
            //self.lock.lock();
            NSNumber *raidMaxTime = [[Settings sharedInstance] raidMaxTime];
            if (timeIntervalSince >= ([raidMaxTime intValue] + [delayTemp intValue])) {
                locked = false;
                [[DeviceState sharedInstance] setWaitForData:false];
                NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
                [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
                syslog(@"[WARN] Pokestop loading timed out...");
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
                locked = [[DeviceState sharedInstance] waitForData];
                if (!locked) {
                    success = true;
                    [[DeviceState sharedInstance] setDelayQuest:true];
                    [[DeviceState sharedInstance] setFailedCount:0];
                    syslog(@"[INFO] Pokestop loaded after %f", [[NSDate date] timeIntervalSinceDate:start]);
                    sleep(1);
                }
            }
            //self.lock.unlock();
        }
        
        if (success) {
            syslog(@"[INFO] Spinning Pokestop");
            NSDate *lastDeployTime = [[DeviceState sharedInstance] lastDeployTime];
            NSNumber *luckyEggsCount = [[DeviceState sharedInstance] luckyEggsCount];
            NSNumber *spinCount = [[DeviceState sharedInstance] spinCount];
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:lastDeployTime];
            if (([luckyEggsCount intValue] >= 1 && timeIntervalSince >= 2000) ||
                ([spinCount intValue] >= 400 && [[[Device sharedInstance] level] intValue] >= 20)) {
                /* TODO: Egg Deploy
                [Jarvis__ getToMainScreen];
                syslog(@"[INFO] Clearing Items for UQ");
                if ([Jarvis__ eggDeploy]) {
                    [[DeviceState sharedInstance] setLastDeployTime:[NSDate date]];
                    [[DeviceState sharedInstance] setLuckyEggsCount:[Utils decrementInt:luckyEggsCount]];
                } else {
                    [[DeviceState sharedInstance] setLuckyEggsCount:0];
                }
                */
                [[DeviceState sharedInstance] setSpinCount:0];
                [[DeviceState sharedInstance] setUltraQuestSpin:true];
                [NSThread sleepForTimeInterval:1];
                NSNumber *attempts = @0;
                while ([[NSDate date] timeIntervalSinceDate:start] < 15.0 + [delay intValue]) {
                    //self.lock.lock();
                    if (![[DeviceState sharedInstance] gotItems]) {
                        //self.lock.unlock();
                        if ([attempts intValue] % 5 == 0) {
                            syslog(@"[DEBUG] Waiting to spin...");
                        }
                        sleep(2);
                    } else {
                        //self.lock.unlock();
                        syslog(@"[INFO] Successfully spun Pokestop");
                        [[DeviceState sharedInstance] setUltraQuestSpin:false];
                        //_spins = _spins + 1;
                        //sleep(3 * [[Device sharedInstance] delayMultiplier;
                        break;
                    }
                    attempts = [Utils incrementInt:attempts];
                }
                [[DeviceState sharedInstance] setUltraQuestSpin:false];
                if (![[DeviceState sharedInstance] gotItems]) {
                    syslog(@"[ERROR] Failed to spin Pokestop");
                }
            }
        }
        
    } else {
        syslog(@"[DEBUG] Sleep 3 seconds before skipping...");
        [NSThread sleepForTimeInterval:3];
    }
}

-(void)handleIVJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
    NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:firstWarningDate];
    NSNumber *maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
    if (hasWarning &&
        firstWarningDate != nil &&
        timeSince >= [maxWarningTimeRaid intValue] &&
        [[Settings sharedInstance] enableAccountManager]) {
        syslog(@"[WARN] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = data[@"lat"] ?: @0;
    NSNumber *lon = data[@"lon"] ?: @0;
    syslog(@"[INFO] Scanning for IV at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    [[DeviceState sharedInstance] setWaitRequiresPokemon:true];
    // REVIEW: Not used - _targetMaxDisance = [[Settings sharedInstance] targetMaxDistance];
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitForData:true];
    // REVIEW: Not used - _encounterDelay = [[Settings sharedInstance] encounterDelay];
    //self.lock.unlock();
    syslog(@"[INFO] Scanning prepared");
    
    bool locked = true;
    while (locked) {
        //self.lock.lock();
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        NSNumber *pokemonMaxTime = [[Settings sharedInstance] pokemonMaxTime];
        if (timeIntervalSince >= [pokemonMaxTime intValue]) {
            locked = false;
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            syslog(@"[WARN] Pokemon loading timed out.");
            NSMutableDictionary *raidData = [[NSMutableDictionary alloc] init];
            raidData[@"uuid"] = [[Device sharedInstance] uuid];
            raidData[@"action"] = action;
            raidData[@"lat"] = lat;
            raidData[@"lon"] = lon;
            raidData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                          dict:raidData
                      blocking:true
                    completion:^(NSDictionary *result) {}
            ];
        } else {
            locked = [[DeviceState sharedInstance] waitForData];;
            if (!locked) {
                [[DeviceState sharedInstance] setFailedCount:0];
                syslog(@"[INFO] Pokemon loaded after %f", timeIntervalSince);
            }
        }
        sleep(1);
    }
}

-(void)handleSwitchAccount:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    [[Device sharedInstance] setUsername:nil];
    [[Device sharedInstance] setIsLoggedIn:false];
    //_isQuestInit = false;
    [[NSUserDefaults standardUserDefaults] synchronize];
    [DeviceState logout];
}

-(void)handleGatherToken:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
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
    syslog(@"[INFO] Received ptcToken, swapping account...");
    [DeviceState logout];
}

@end
