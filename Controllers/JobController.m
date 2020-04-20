//
//  JobController.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "JobController.h"

@implementation JobController

static dispatch_queue_t _getJobQueue;
static int _eggInterval = 901;//1801; // 30 mins 1 second
static NSTimer *_timer = nil;

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
    if ((self = [super init])) {
        _getJobQueue = dispatch_queue_create("getjob_queue", NULL);
    }
    return self;
}

-(void)initialize
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSMutableDictionary *initData = [[NSMutableDictionary alloc] init];
    initData[@"uuid"] = [[Device sharedInstance] uuid];
    initData[@"username"] = [[Device sharedInstance] username];
    initData[@"type"] = TYPE_INIT;
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:initData
              blocking:true
            completion:^(NSDictionary *result) {
        //syslog(@"[DEBUG] Response from init: %@", result);
        if (result == nil) {
            syslog(@"[ERROR] Failed to connect to backend! Restarting in 30 seconds.");
            sleep(30);
            //[[Device sharedInstance] setShouldExit:true];
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
        dispatch_semaphore_signal(sem);
    }];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if ([[Device sharedInstance] shouldExit]) {
        [[Device sharedInstance] setShouldExit:false];
        sleep(5);
        [DeviceState restart];
    }
}

-(void)getAccount
{
    //syslog(@"[INFO] Sending 'get_account' post request.");
    if (([[[Device sharedInstance] username] isNullOrEmpty] ||
         [[[Device sharedInstance] username] isEqualToString:@"fail"]) &&
         [[Settings sharedInstance] enableAccountManager]) {
        NSMutableDictionary *getAccountData = [[NSMutableDictionary alloc] init];
        getAccountData[@"uuid"] = [[Device sharedInstance] uuid];
        getAccountData[@"username"] = [[Device sharedInstance] username];
        getAccountData[@"min_level"] = [[Device sharedInstance] minLevel];
        getAccountData[@"max_level"] = [[Device sharedInstance] maxLevel];
        getAccountData[@"type"] = TYPE_GET_ACCOUNT;
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
                    [DeviceState restart];
                    return;
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
                sleep(1);
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
                sleep(5);
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
        [[DeviceState sharedInstance] setNoItemsCount:@0];
        [[DeviceState sharedInstance] setNoQuestCount:@0];

        // Grab an account from the backend controller.
        [self getAccount];
        
        syslog(@"[INFO] Starting job handler.");
        // Start grabbing jobs from the backend controller.
        while (![[Device sharedInstance] shouldExit]) {
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            __block NSDictionary *data = nil;
            if ([[DeviceState sharedInstance] needsLogout]) {
                syslog(@"[INFO] Logging out...");
                CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                [DeviceState logout];
            }
            NSMutableDictionary *jobData = [[NSMutableDictionary alloc] init];
            jobData[@"uuid"] = [[Device sharedInstance] uuid];
            jobData[@"username"] = [[Device sharedInstance] username];
            jobData[@"type"] = TYPE_GET_JOB;
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                          dict:jobData
                      blocking:true
                    completion:^(NSDictionary *result) {
                //syslog(@"[DEBUG] get_job response: %@", result);
                if (result == nil) {
                    NSNumber *failedGetJobCount = [[DeviceState sharedInstance] failedGetJobCount];
                    if ([failedGetJobCount intValue] == 10) {
                        syslog(@"[ERROR] Failed to get job 10 times in a row. Exiting...");
                        [[Device sharedInstance] setShouldExit:true];
                        dispatch_semaphore_signal(sem);
                        return;
                    } else {
                        syslog(@"[ERROR] Failed to get a job.");
                        NSNumber *failedToGetJobCount = [[DeviceState sharedInstance] failedGetJobCount];
                        [[DeviceState sharedInstance] setFailedGetJobCount:[Utils incrementInt:failedToGetJobCount]];
                        sleep(5 * [[[Device sharedInstance] delayMultiplier] intValue]);
                        [[Device sharedInstance] setShouldExit:true];
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
                            if ([currentLevel intValue] != 0 && // TODO: Remove
                                ([currentLevel intValue] < [minLevel intValue] ||
                                 [currentLevel intValue] > [maxLevel intValue])) {
                                syslog(@"[WARN] Account is outside min/max level range. Logging out!");
                                CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
                                [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
                                [DeviceState logout];
                                return;
                            }
                        }
                    }
                }
                
                [[DeviceState sharedInstance] setFailedGetJobCount:@0];
                if (data == nil) {
                    syslog(@"[WARN] No job left (Result: %@)", result);
                    sleep(5);
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
                } else if ([action isEqualToString:@"scan_quest"] ||
                           [action isEqualToString:@"leveling"]) {
                    syslog(@"[DEBUG] [STATUS] Quest/Leveling");
                    [self handleQuestJob:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"switch_account"]) {
                    syslog(@"[DEBUG] [STATUS] Switching Accounts");
                    [self handleSwitchAccount:action withData:data hasWarning:hasWarning];
                //} else if ([action isEqualToString:@"leveling"]) {
                //    syslog(@"[DEBUG] [STATUS] Leveling");
                //    [self handleLevelingJob:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"scan_iv"]) {
                    syslog(@"[DEBUG] [STATUS] IV");
                    [self handleIVJob:action withData:data hasWarning:hasWarning];
                } else if ([action isEqualToString:@"gather_token"]) {
                    syslog(@"[DEBUG] [STATUS] Token");
                    [self handleGatherToken:action withData:data hasWarning:hasWarning];
                //} else {
                //    syslog(@"[WARN] Unknown action received: %@", action);
                }
                
                dispatch_semaphore_signal(sem);
                
                NSNumber *emptyGmoCount = [[DeviceState sharedInstance] emptyGmoCount];
                int maxEmptyGMO = [[Settings sharedInstance] maxEmptyGMO];
                if ([emptyGmoCount intValue] >= maxEmptyGMO) {
                    syslog(@"[WARN] Got Empty GMO %@ times in a row. Restarting...", emptyGmoCount);
                    [DeviceState restart];
                }
                
                NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
                int maxFailedCount = [[Settings sharedInstance] maxFailedCount];
                if ([failedCount intValue] >= maxFailedCount) {
                    syslog(@"[ERROR] Failed %@ times in a row. Restarting...", failedCount);
                    [DeviceState restart];
                }
                
                sleep(1);
            }];
            
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            sleep(1);
        }
    });
}

-(void)startEggTimer
{
    if (_timer != nil) {
        return;
    }
    _timer = [NSTimer scheduledTimerWithTimeInterval:_eggInterval
                                              target:[UIC2 class]
                                            selector:@selector(eggDeploy)
                                            userInfo:nil
                                             repeats:YES];
    syslog(@"[INFO] Deploying lucky egg from scheduled timer.");
    if (![UIC2 eggDeploy]) {
       syslog(@"[ERROR] Failed to deploy lucky egg.");
    }
}

-(void)sendJobFailed:(NSString *)action withLat:(NSNumber *)lat andLon:(NSNumber *)lon
{
    NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
    failedData[@"uuid"] = [[Device sharedInstance] uuid];
    failedData[@"username"] = [[Device sharedInstance] username];
    failedData[@"action"] = action;
    failedData[@"lat"] = lat;
    failedData[@"lon"] = lon;
    failedData[@"type"] = TYPE_JOB_FAILED;
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:failedData
              blocking:true
            completion:^(NSDictionary *result) {}
    ];
}


#pragma mark Job Handlers

-(void)handlePokemonJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    if (hasWarning &&
        [[Settings sharedInstance] enableAccountManager] &&
        ![[Settings sharedInstance] allowWarnedAccounts]) {
        syslog(@"[WARN] Account has a warning and tried to scan for Pokemon. Logging out!");
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        return;
    }
    
    NSNumber *lat = data[@"lat"];
    NSNumber *lon = data[@"lon"];
    syslog(@"[INFO] Scanning for Pokemon at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    [[DeviceState sharedInstance] setWaitRequiresPokemon:true];
    [[DeviceState sharedInstance] setPokemonEncounterId:nil];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]]];
    [[DeviceState sharedInstance] setWaitForData:true];
    syslog(@"[INFO] Scanning prepared");
    
    bool locked = true;
    int pokemonMaxTime = [[Settings sharedInstance] pokemonMaxTime];
    while (locked) {
        sleep(1);
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        
        if (timeIntervalSince >= pokemonMaxTime) {
            locked = false;
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            syslog(@"[WARN] Pokemon loading timed out.");
            [self sendJobFailed:action withLat:lat andLon:lon];
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
    int maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
    if (hasWarning &&
        firstWarningDate != nil &&
        timeSince >= maxWarningTimeRaid &&
        [[Settings sharedInstance] enableAccountManager] &&
        ![[Settings sharedInstance] allowWarnedAccounts]) {
        syslog(@"[WARN] Account has warning and is over maxWarningTimeRaid (%d). Logging out!", maxWarningTimeRaid);
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        return;
    }
    
    NSNumber *lat = data[@"lat"] ?: 0;
    NSNumber *lon = data[@"lon"] ?: 0;
    syslog(@"[INFO] Scanning for Raid at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setWaitForData:true];
    syslog(@"[INFO] Scanning prepared.");
    
    bool locked = true;
    int raidMaxTime = [[Settings sharedInstance] raidMaxTime];
    while (locked) {
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince >= raidMaxTime) {
            locked = false;
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            syslog(@"[WARN] Raids loading timed out.");
            [self sendJobFailed:action withLat:lat andLon:lon];
        } else {
            locked = [[DeviceState sharedInstance] waitForData];
            if (!locked) {
                [[DeviceState sharedInstance] setFailedCount:@0];
                syslog(@"[INFO] Raids loaded after %f", timeIntervalSince);
            }
        }
    }
}

/*
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
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
    }

    if ([[Settings sharedInstance] deployEggs]) {
        NSDate *lastDeployTime = [[Device sharedInstance] lastEggDeployTime];
        NSNumber *luckyEggsCount = [[Device sharedInstance] luckyEggsCount];
        //NSNumber *spinCount = [[DeviceState sharedInstance] spinCount];
        NSNumber *level = [[Device sharedInstance] level];
        NSTimeInterval eggTimeIntervalSince = [[NSDate date] timeIntervalSinceDate:lastDeployTime];
        syslog(@"[INFO] Lucky Eggs Count: %@ EggTimeSince: %f Level: %@ LastDeploy: %@",
               luckyEggsCount, eggTimeIntervalSince, level, lastDeployTime);
        if ([luckyEggsCount intValue] > 0 &&
            [level intValue] >= 9 && [level intValue] < 30 &&
            (lastDeployTime == nil ||
            eggTimeIntervalSince == NAN ||
            eggTimeIntervalSince >= _eggInterval)) {
            syslog(@"[INFO] Deploying lucky egg.");
            if ([UIC2 eggDeploy]) {
                [[Device sharedInstance] setLastEggDeployTime:[NSDate date]];
                [[Device sharedInstance] setLuckyEggsCount:[Utils decrementInt:luckyEggsCount]];
            }
        }
    }
    
    NSNumber *minDelayLogout = [[Settings sharedInstance] minDelayLogout];
    if ([delay intValue] >= [minDelayLogout intValue] && [[Settings sharedInstance] enableAccountManager]) {
        syslog(@"[WARN] Switching account. Delay too large. (Delay: %@ MinDelayLogout: %@)", delay, minDelayLogout);
        NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
        failedData[@"uuid"] = [[Device sharedInstance] uuid];
        failedData[@"action"] = action;
        failedData[@"lat"] = lat;
        failedData[@"lon"] = lon;
        failedData[@"type"] = TYPE_JOB_FAILED;
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:failedData
                  blocking:true
                completion:^(NSDictionary *result) {}
        ];
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
    }
    
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setNewCreated:false];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
    [[DeviceState sharedInstance] setPokemonEncounterId:nil];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setWaitForData:true];
    syslog(@"[INFO] Scanning prepared");
    
    NSDate *start = [NSDate date];
    bool success = false;
    bool locked = true;
    bool found = false;
    while (locked) {
        sleep(1 * [[[Device sharedInstance] delayMultiplier] intValue]);
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince <= 5) {
            continue;
        }
        if (!found && (timeIntervalSince <= [delay doubleValue])) {
            NSNumber *left = @([delay doubleValue] - timeIntervalSince);
            syslog(@"[INFO] Delaying by %@ seconds.", left);
            while (!found && ([[NSDate date] timeIntervalSinceDate:start] <= [delay doubleValue])) {
                locked = [[DeviceState sharedInstance] gotQuestEarly];
                if (locked) {
                    sleep(1);
                } else {
                    found = true;
                }
            }
            continue;
        }
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
            failedData[@"type"] = TYPE_JOB_FAILED;
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
                [[DeviceState sharedInstance] setFailedCount:@0];
                syslog(@"[INFO] Pokestop loaded after %f", timeIntervalSince);
            }
        }
    }

    if ([[DeviceState sharedInstance] gotQuest]) {
        [[DeviceState sharedInstance] setNoQuestCount:@0];
    } else {
        NSNumber *noQuestCount = [[DeviceState sharedInstance] noQuestCount];
        [[DeviceState sharedInstance] setNoQuestCount:[Utils incrementInt:noQuestCount]];
    }
    
    NSNumber *noQuestCount = [[DeviceState sharedInstance] noQuestCount];
    NSNumber *maxNoQuestCount = [[Settings sharedInstance] maxNoQuestCount];
    if ([noQuestCount intValue] >= [maxNoQuestCount intValue]) {
        syslog(@"[WARN] Stuck somewhere. Restarting...");
        [DeviceState logout];
    }
    
    if (success) {
        bool gotQuest = [[DeviceState sharedInstance] gotQuest];
        syslog(@"[INFO] Got quest data: %@", gotQuest ? @"Yes" : @"No");
    }
}
*/

-(void)handleQuestJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
    NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:firstWarningDate];
    int maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
    if (hasWarning &&
        firstWarningDate != nil &&
        timeSince >= maxWarningTimeRaid &&
        [[Settings sharedInstance] enableAccountManager] &&
        ![[Settings sharedInstance] allowWarnedAccounts]) {
        syslog(@"[WARN] Account has warning and is over maxWarningTimeRaid (%d). Logging out!", maxWarningTimeRaid);
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        return;
    }
    
    [[DeviceState sharedInstance] setDelayQuest:true];
    NSNumber *lat = data[@"lat"];
    NSNumber *lon = data[@"lon"];
    NSNumber *delay = data[@"delay"];
    if ([action isEqualToString:@"scan_quest"]) {
        syslog(@"[INFO] Scanning for Quest at %@ %@ in %@ seconds", lat, lon, delay);
    } else {
        syslog(@"[INFO] Leveling at %@ %@ in %@ seconds", lat, lon, delay);
    }
    //NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
    
    if (![[DeviceState sharedInstance] isQuestInit]) {
        [[DeviceState sharedInstance] setIsQuestInit:true];
        if ([[Settings sharedInstance] ultraQuests]) {
            delay = @30.0;
        } else {
            delay = @0.0;
        }
    } else {
        CLLocation *newLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        CLLocation *lastQuestLocation = [[DeviceState sharedInstance] lastQuestLocation];
        CLLocation *lastLocation = [Utils createCoordinate:lastQuestLocation.coordinate.latitude
                                                       lon:lastQuestLocation.coordinate.longitude];
        double questDistance = [newLocation distanceFromLocation:lastLocation];
        if ([[DeviceState sharedInstance] gotQuest]) {
            [[DeviceState sharedInstance] setNoQuestCount:@0];
        } else {
            NSNumber *noQuestCount = [[DeviceState sharedInstance] noQuestCount];
            [[DeviceState sharedInstance] setNoQuestCount:[Utils incrementInt:noQuestCount]];
        }
        [[DeviceState sharedInstance] setGotQuest:false];
        
        /*
        NSNumber *noQuestCount = [[DeviceState sharedInstance] noQuestCount];
        NSNumber *maxNoQuestCount = [[Settings sharedInstance] maxNoQuestCount];
        if ([noQuestCount intValue] >= [maxNoQuestCount intValue]) {
            syslog(@"[WARN] Stuck somewhere %@/%@ no quests. Restarting...", noQuestCount, maxNoQuestCount);
            [DeviceState restart];
            return;
        }
        */
        
        [[DeviceState sharedInstance] setSkipSpin:false];
        
        syslog(@"[DEBUG] Quest Distance: %f", questDistance);
        if (questDistance <= 30.0) {
            delay = @0;
            [[DeviceState sharedInstance] setSkipSpin:true];
            syslog(@"[DEBUG] Quest Distance: %f < 40.0m already spun. Go to next stop", questDistance);
        } else if (questDistance <= 1000.0) {
            delay = @((questDistance / 1000.0) * 60.0);
        } else if (questDistance <= 2000.0) {
            delay = @((questDistance / 2000.0) * 90.0);
        } else if (questDistance <= 4000.0) {
            delay = @((questDistance / 4000.0) * 120.0);
        } else if (questDistance <= 5000.0) {
            delay = @((questDistance / 5000.0) * 150.0);
        } else if (questDistance <= 8000.0) {
            delay = @((questDistance / 8000.0) * 360.0);
        } else if (questDistance <= 10000.0) {
            delay = @((questDistance / 10000.0) * 420.0);
        } else if (questDistance <= 15000.0) {
            delay = @((questDistance / 15000.0) * 480.0);
        } else if (questDistance <= 20000.0) {
            delay = @((questDistance / 20000.0) * 600.0);
        } else if (questDistance <= 25000.0) {
            delay = @((questDistance / 25000.0) * 900.0);
        } else if (questDistance <= 30000.0) {
            delay = @((questDistance / 30000.0) * 1020.0);
        } else if (questDistance <= 40000.0) {
            delay = @((questDistance / 40000.0) * 1140.0);
        } else if (questDistance <= 65000.0) {
            delay = @((questDistance / 65000.0) * 1320.0);
        } else if (questDistance <= 81000.0) {
            delay = @((questDistance / 81000.0) * 1800.0);
        } else if (questDistance <= 100000.0) {
            delay = @((questDistance / 100000.0) * 2400.0);
        } else if (questDistance <= 220000.0) {
            delay = @((questDistance / 220000.0) * 2700.0);
        } else {
            delay = @7200.0;
        }
    }
    
    if (![[DeviceState sharedInstance] skipSpin]) {
        syslog(@"[INFO] Scanning for Quest at %@ %@ in %@ seconds", lat, lon, delay);
        [[DeviceState sharedInstance] setLastQuestLocation:[Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]]];
        
        // TODO: Check warning
        
        int minDelayLogout = [[Settings sharedInstance] minDelayLogout];
        if ([delay intValue] >= minDelayLogout && [[Settings sharedInstance] enableAccountManager]) {
            syslog(@"[WARN] Switching account. Delay too large. (Delay: %@ MinDelayLogout: %d)", delay, minDelayLogout);
            [self sendJobFailed:action withLat:lat andLon:lon];
            CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
            [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
            [DeviceState logout];
            return;
        }
        
        CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        [[DeviceState sharedInstance] setNewCreated:false];
        [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
        [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
        [[DeviceState sharedInstance] setPokemonEncounterId:nil];
        //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
        [[DeviceState sharedInstance] setWaitForData:true];
        syslog(@"[INFO] Scanning prepared");
        
        NSDate *start = [NSDate date];
        bool success = false;
        bool locked = true;
        bool found = false;
        while (locked) {
            sleep(1 * [[[Device sharedInstance] delayMultiplier] intValue]);
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
            if (timeIntervalSince <= 5) {
                continue;
            }
            if (!found && (timeIntervalSince <= [delay doubleValue])) {
                NSNumber *left = @([delay doubleValue] - timeIntervalSince);
                syslog(@"[INFO] Delaying by %@ seconds.", left);
                while (!found && ([[NSDate date] timeIntervalSinceDate:start] <= [delay doubleValue])) {
                    locked = [[DeviceState sharedInstance] gotQuestEarly];
                    if (locked) {
                        sleep(1);
                    } else {
                        found = true;
                    }
                }
                continue;
            }
            double raidMaxTime = [[Settings sharedInstance] raidMaxTime];
            NSNumber *totalDelay = @(raidMaxTime + [delay doubleValue]);
            if (!found && timeIntervalSince >= [totalDelay doubleValue]) {
                locked = false;
                [[DeviceState sharedInstance] setWaitForData:false];
                NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
                [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
                syslog(@"[WARN] Pokestop loading timed out.");
                [self sendJobFailed:action withLat:lat andLon:lon];
            } else {
                locked = [[DeviceState sharedInstance] waitForData];
                if (!locked) {
                    [[DeviceState sharedInstance] setDelayQuest:true];
                    success = true;
                    [[DeviceState sharedInstance] setFailedCount:@0];
                    syslog(@"[INFO] Pokestop loaded after %f", timeIntervalSince);
                }
            }
        }
        
        if (success) {
            if ([[Settings sharedInstance] deployEggs]) {
                NSDate *lastDeployTime = [[Device sharedInstance] lastEggDeployTime];
                NSNumber *luckyEggsCount = [[Device sharedInstance] luckyEggsCount];
                //NSNumber *spinCount = [[DeviceState sharedInstance] spinCount];
                NSNumber *level = [[Device sharedInstance] level];
                NSTimeInterval eggTimeIntervalSince = [[NSDate date] timeIntervalSinceDate:lastDeployTime];
                syslog(@"[INFO] Lucky Eggs Count: %@ EggTimeSince: %f Level: %@ LastDeploy: %@",
                       luckyEggsCount, eggTimeIntervalSince, level, lastDeployTime);
                if (([luckyEggsCount intValue] > 0 &&
                    [level intValue] >= 9 && [level intValue] < 30) ||
                    eggTimeIntervalSince >= _eggInterval) {
                    [self startEggTimer];
                }
            }
            
            bool gotQuest = [[DeviceState sharedInstance] gotQuest];
            syslog(@"[INFO] Got quest data: %@", gotQuest ? @"Yes" : @"No");
        }
        
    }
}

-(void)handleLevelingJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    [[DeviceState sharedInstance] setDelayQuest:false];
    //degreePerMeter = 83267.0991559005
    NSNumber *lat = data[@"lat"] ?: 0;
    NSNumber *lon = data[@"lon"] ?: 0;
    NSNumber *delay = data[@"delay"] ?: @0.0;
    //NSString *fortType = data[@"fort_type"] ?: @"P";
    NSString *targetFortId = data[@"fort_id"] ?: @"";
    [[DeviceState sharedInstance] setTargetFortId:targetFortId];
    //syslog(@"[DEBUG] [RES1] Location: %@ %@ Delay: %@ FortType: %@ FortId: %@", lat, lon, delay, fortType, targetFortId);
    
    if (![[DeviceState sharedInstance] isQuestInit]) {
        [[DeviceState sharedInstance] setIsQuestInit:true];
        delay = @30.0;
    } else {
        CLLocation *newLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        CLLocation *lastLocation = [[DeviceState sharedInstance] lastQuestLocation];
        NSNumber *questDistance = [NSNumber numberWithDouble:[newLocation distanceFromLocation:lastLocation]];
        
        // Check if previous spin had quest data
        if ([[DeviceState sharedInstance] gotItems]) {
            [[DeviceState sharedInstance] setNoItemsCount:@0];
        } else {
            NSNumber *noItemsCount = [[DeviceState sharedInstance] noItemsCount];
            [[DeviceState sharedInstance] setNoItemsCount:[Utils incrementInt:noItemsCount]];
        }
        [[DeviceState sharedInstance] setGotItems:false];
        
        NSNumber *noItemsCount = [[DeviceState sharedInstance] noItemsCount];
        int maxNoQuestCount = [[Settings sharedInstance] maxNoQuestCount];
        syslog(@"[DEBUG] NoItemsCount: %@/%d", noItemsCount, maxNoQuestCount);
        /*
        if ([noItemsCount intValue] >= [maxNoQuestCount intValue]) {
            [[DeviceState sharedInstance] setIsQuestInit:false];
            [[DeviceState sharedInstance] setNoItemsCount:@0];
            [[Device sharedInstance] setShouldExit:true];
            syslog(@"[WARN] Stuck somewhere %@/%@ no items. Restarting accounts...",
                   noItemsCount,
                   [[Settings sharedInstance] maxNoQuestCount]);
            [DeviceState restart];
            return;
        }
        */
        
        [[DeviceState sharedInstance] setSkipSpin:false];
        syslog(@"[DEBUG] Quest Distance: %@", questDistance);
        if ([questDistance doubleValue] <= 5.0) {
            delay = @0.0;
            [[DeviceState sharedInstance] setSkipSpin:true];
            syslog(@"[DEBUG] Quest Distance: %@m < 30.0m Already spun this pokestop. Go to next pokestop.", questDistance);
            [[DeviceState sharedInstance] setGotItems:true];
        } else if ([questDistance intValue] <= 100.0) {
            delay = @3.0;
        } else if ([questDistance intValue] <= 1000.0) {
            delay = @(([questDistance intValue] / 1000.0) * 60.0);
        } else if ([questDistance intValue] <= 2000.0) {
            delay = @(([questDistance intValue] / 2000.0) * 90.0);
        } else if ([questDistance intValue] <= 4000.0) {
            delay = @(([questDistance intValue] / 4000.0) * 120.0);
        } else if ([questDistance intValue] <= 5000.0) {
            delay = @(([questDistance intValue] / 5000.0) * 150.0);
        } else if ([questDistance intValue] <= 8000.0) {
            delay = @(([questDistance intValue] / 8000.0) * 360.0);
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
        int maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
        if (hasWarning &&
            firstWarningDate != nil &&
            timeSince >= maxWarningTimeRaid &&
            [[Settings sharedInstance] enableAccountManager]) {
            syslog(@"[WARN] Account has a warning and is over maxWarningTimeRaid (%d). Logging out!", maxWarningTimeRaid);
            CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
            [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
            [[Device sharedInstance] setUsername:nil];
            [[Device sharedInstance] setIsLoggedIn:false];
            [[DeviceState sharedInstance] setIsQuestInit:false];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [DeviceState logout];
        }
        
        [[DeviceState sharedInstance] setNewCreated:false];
        [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]]];
        [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
        [[DeviceState sharedInstance] setPokemonEncounterId:nil];
        //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance] ?: @250.0;
        [[DeviceState sharedInstance] setWaitForData:true];
        syslog(@"[INFO] Scanning prepared");
        
        NSDate *start = [NSDate date];
        NSNumber *delayTemp = delay;
        if ([[Settings sharedInstance] ultraQuests]) {
            delayTemp = @0;
        }
        bool success = false;
        bool locked = true;
        while (locked) {
            usleep(100000 * [[[Device sharedInstance] delayMultiplier] intValue]);
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
            if (timeIntervalSince <= [delayTemp intValue]) {
                NSNumber *left = @([delayTemp intValue] - timeIntervalSince);
                syslog(@"[DEBUG] Delaying by %@", left);
                usleep(MIN(10, [left intValue]) * 1000000.0);
                //usleep(MIN(10.0, left) * 1000000));
                continue;
            }
            int raidMaxTime = [[Settings sharedInstance] raidMaxTime];
            if (timeIntervalSince >= (raidMaxTime + [delayTemp intValue])) {
                locked = false;
                [[DeviceState sharedInstance] setWaitForData:false];
                NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
                [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
                syslog(@"[WARN] Pokestop loading timed out...");
                [self sendJobFailed:action withLat:lat andLon:lon];
            } else {
                locked = [[DeviceState sharedInstance] waitForData];
                // mizu has locked = false too for some reason?
                //locked = false;
                if (!locked) {
                    success = true;
                    [[DeviceState sharedInstance] setDelayQuest:true];
                    [[DeviceState sharedInstance] setFailedCount:@0];
                    syslog(@"[INFO] Pokestop loaded after %f", [[NSDate date] timeIntervalSinceDate:start]);
                    //sleep(1);
                }
            }
        }
        
        if (success) {
            syslog(@"[INFO] Spinning Pokestop");
            NSDate *lastDeployTime = [[Device sharedInstance] lastEggDeployTime];
            NSNumber *luckyEggsCount = [[Device sharedInstance] luckyEggsCount];
            //NSNumber *spinCount = [[DeviceState sharedInstance] spinCount];
            NSNumber *level = [[Device sharedInstance] level];
            NSTimeInterval eggTimeIntervalSince = [[NSDate date] timeIntervalSinceDate:lastDeployTime];
            syslog(@"[INFO] Lucky Eggs Count: %@ EggTimeSince: %f Level: %@ LastDeploy: %@",
                   luckyEggsCount, eggTimeIntervalSince, level, lastDeployTime);
            if (([luckyEggsCount intValue] > 0 &&
                [level intValue] >= 9 && [level intValue] < 30) ||
                eggTimeIntervalSince >= _eggInterval) {
                [self startEggTimer];
            }
            /*
            if (([luckyEggsCount intValue] > 0 &&
                [level intValue] >= 9 && [level intValue] < 30) &&
                (lastDeployTime == nil ||
                eggTimeIntervalSince == NAN ||
                eggTimeIntervalSince >= _eggInterval)) {
                syslog(@"[INFO] Deploying lucky egg.");
                if ([UIC2 eggDeploy]) {
                    [[Device sharedInstance] setLastEggDeployTime:[NSDate date]];
                    [[Device sharedInstance] setLuckyEggsCount:[Utils decrementInt:luckyEggsCount]];
                } else {
                    //syslog(@"[ERROR] Failed to deploy lucky egg.");
                }
            }
            */
            /*
            [[DeviceState sharedInstance] setSpinCount:@0];
            sleep(1 * [[[Device sharedInstance] delayMultiplier] intValue]);
            int attempts = 0;
            while ([[NSDate date] timeIntervalSinceDate:start] < 15.0 + [delay intValue]) {
                if (![[DeviceState sharedInstance] gotItems]) {
                    if (attempts % 5 == 0) {
                        syslog(@"[DEBUG] Waiting to spin...");
                    }
                    sleep(1);
                } else {
            */
                    syslog(@"[INFO] Successfully spun Pokestop");
                    NSNumber *spins = [[DeviceState sharedInstance] spinCount];
                    [[DeviceState sharedInstance] setSpinCount:[Utils incrementInt:spins]];
                    //sleep(1 * [[[Device sharedInstance] delayMultiplier] intValue]);
            /*
                    break;
                }
                attempts++;
            }
            if (![[DeviceState sharedInstance] gotItems]) {
                syslog(@"[ERROR] Failed to spin Pokestop");
            }
            */
        }
    } else {
        syslog(@"[DEBUG] Sleep 3 seconds before skipping...");
        sleep(3);
    }
}

-(void)handleIVJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    // TODO: Make reusable checkAccountWarningTime method
    NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
    NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:firstWarningDate];
    int maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
    if (hasWarning &&
        firstWarningDate != nil &&
        timeSince >= maxWarningTimeRaid &&
        [[Settings sharedInstance] enableAccountManager] &&
        ![[Settings sharedInstance] allowWarnedAccounts]) {
        syslog(@"[WARN] Account has warning and is over maxWarningTimeRaid (%d). Logging out!", maxWarningTimeRaid);
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
    }
    
    NSNumber *lat = data[@"lat"] ?: @0;
    NSNumber *lon = data[@"lon"] ?: @0;
    syslog(@"[INFO] Scanning for IV at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    [[DeviceState sharedInstance] setWaitRequiresPokemon:true];
    // REVIEW: Not used - _targetMaxDisance = [[Settings sharedInstance] targetMaxDistance];
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitForData:true];
    syslog(@"[INFO] Scanning prepared");
    
    bool locked = true;
    while (locked) {
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        int pokemonMaxTime = [[Settings sharedInstance] pokemonMaxTime];
        if (timeIntervalSince >= pokemonMaxTime) {
            locked = false;
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            syslog(@"[WARN] Pokemon loading timed out.");
            [self sendJobFailed:action withLat:lat andLon:lon];
        } else {
            locked = [[DeviceState sharedInstance] waitForData];;
            if (!locked) {
                [[DeviceState sharedInstance] setFailedCount:@0];
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
    [[DeviceState sharedInstance] setIsQuestInit:false];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [DeviceState logout];
}

-(void)handleGatherToken:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    NSMutableDictionary *tokenData = [[NSMutableDictionary alloc] init];
    tokenData[@"uuid"] = [[Device sharedInstance] uuid];
    tokenData[@"username"] = [[Device sharedInstance] username];
    tokenData[@"ptcToken"] = [[Device sharedInstance] ptcToken];
    tokenData[@"type"] = TYPE_PTC_TOKEN;
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:tokenData
              blocking:true
            completion:^(NSDictionary *result) {}
    ];
    syslog(@"[INFO] Received ptcToken, swapping account...");
    [DeviceState logout];
}

@end
