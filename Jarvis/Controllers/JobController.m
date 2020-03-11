//
//  JobController.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "JobController.h"

@implementation JobController

-(id)init
{
    NSLog(@"[Jarvis] [JobController] init");
    if ((self = [super init]))
    {
    }
    
    return self;
}

-(void)handlePokemonJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    if (hasWarning && [[Settings sharedInstance] enableAccountManager]) {
        NSLog(@"[Jarvis] [JobController] Account has a warning and tried to scan for Pokemon. Logging out!");
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = data[@"lat"];
    NSNumber *lon = data[@"lon"];
    NSLog(@"[Jarvis] [JobController] Scanning for Pokemon at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    [[DeviceState sharedInstance] setWaitRequiresPokemon:true];
    [[DeviceState sharedInstance] setPokemonEncounterId:nil];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]]];
    [[DeviceState sharedInstance] setWaitForData:true];
    //self.lock.unlock();
    NSLog(@"[Jarvis] [JobController] Scanning prepared");
    
    BOOL locked = true;
    while (locked) {
        [NSThread sleepForTimeInterval:1];
        //self.lock.lock();
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince >= 30) {
            locked = false;
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            NSLog(@"[Jarvis] [JobController] Pokemon loading timed out.");
            NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
            failedData[@"uuid"] = [[Device sharedInstance] uuid];
            failedData[@"username"] = [[Device sharedInstance] username];
            failedData[@"action"] = action;// TODO: @"scan_pokemon",
            failedData[@"lat"] = lat;
            failedData[@"lon"] = lon;
            failedData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                          dict:failedData
                      blocking:true
                    completion:^(NSDictionary *result) {}
            ];
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
        NSLog(@"[Jarvis] [JobController] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = data[@"lat"] ?: 0;
    NSNumber *lon = data[@"lon"] ?: 0;
    NSLog(@"[Jarvis] [JobController] Scanning for Raid at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setWaitForData:true];
    //self.lock.unlock();
    NSLog(@"[Jarvis] [JobController] Scanning prepared.");
    
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
            NSLog(@"[Jarvis] [JobController] Raids loading timed out.");
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
                NSLog(@"[Jarvis] [JobController] Raids loaded after %f", timeIntervalSince);
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
    NSLog(@"[Jarvis] [JobController] Scanning for Quest at %@ %@ in %@ seconds", lat, lon, delay);
    NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
    
    if (hasWarning && firstWarningDate != nil && [NSDate date]) {
        NSLog(@"[Jarvis] [JobController] Account has a warning and is over maxWarningTimeRaid. Logging out!");
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
        NSNumber *i = @(arc4random_uniform(60));
        [NSThread sleepForTimeInterval:2];
        if ([Jarvis__ getToMainScreen]) {
            NSLog(@"[Jarvis] [JobController] Deploying an egg");
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
            NSLog(@"[Jarvis] [JobController] Egg timer set to %@ UTC for a recheck.", [[DeviceState sharedInstance] eggStart]);
        } else {
            
            NSDate *eggStart = [NSDate dateWithTimeInterval:(960 + [i intValue]) sinceDate:[NSDate date]];
            [[DeviceState sharedInstance] setEggStart:eggStart];
        }
        NSLog(@"[Jarvis] [JobController] Egg timer set to %@ UTC for a recheck.", [[DeviceState sharedInstance] eggStart]);
    }
    
    if (delay >= [[Settings sharedInstance] minDelayLogout] &&
                 [[Settings sharedInstance] enableAccountManager]) {
        NSLog(@"[Jarvis] [JobController] Switching account. Delay too large.");
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
    //self.lock.unlock();
    NSLog(@"[Jarvis] [JobController] Scanning prepared");
    
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
            NSLog(@"[Jarvis] [JobController] Delaying by %@ seconds.", left);

            while (!found && (timeIntervalSince <= [delay doubleValue])) {
                //self.lock.lock();
                locked = [[DeviceState sharedInstance] gotQuestEarly];
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
            [[DeviceState sharedInstance] setWaitForData:false];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            NSLog(@"[Jarvis] [JobController] Pokestop loading timed out.");
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
                NSLog(@"[Jarvis] [JobController] Pokestop loaded after %f", timeIntervalSince);
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
            NSLog(@"[Jarvis] [JobController] Stuck somewhere. Restarting...");
            [DeviceState logout];
        }
        
        //self.lock.unlock();
        if (success) {
            NSNumber *attempts = 0;
            while ([attempts intValue] < 5) {
                attempts = [Utils incrementInt:attempts];
                //self.lock.lock();
                BOOL gotQuest = [[DeviceState sharedInstance] gotQuest];
                NSLog(@"[Jarvis] [JobController] Got quest data: %@", gotQuest ? @"Yes" : @"No");
                if (!gotQuest) {
                    NSLog(@"[Jarvis] [JobController] UltraQuests pokestop re-attempt: %@", attempts);
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
    [[DeviceState sharedInstance] setDelayQuest:false];
    //degreePerMeter = 83267.0991559005
    NSNumber *lat = data[@"lat"] ?: 0;
    NSNumber *lon = data[@"lon"] ?: 0;
    NSLog(@"[Jarvis] [JobController] Scanning for IV at %@ %@", lat, lon);
    NSNumber *delay = data[@"delay"] ?: @0.0;
    NSString *fortType = data[@"fort_type"] ?: @"P";
    NSString *targetFortId = data[@"fort_id"] ?: @"";
    [[DeviceState sharedInstance] setTargetFortId:targetFortId];
    NSLog(@"[Jarvis] [JobController] [RES1] Location: %@ %@ Delay: %@ FortType: %@ FortId: %@", lat, lon, delay, fortType, targetFortId);
    
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
            NSLog(@"[Jarvis] [JobController] Stuck somewhere. Restarting accounts...");
            [DeviceState restart];
            [[Device sharedInstance] setShouldExit:true];
            return;
        }
        
        [[DeviceState sharedInstance] setSkipSpin:false];
        NSLog(@"[Jarvis] [JobController] Quest Distance: %@", questDistance);
        if ([questDistance intValue] <= 5.0) {
            delay = @0.0;
            [[DeviceState sharedInstance] setSkipSpin:true];
            NSLog(@"[Jarvis] [JobController] Quest Distance: %@m < 30.0m Already spun this pokestop. Go to next pokestop.", questDistance);
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
        NSLog(@"[Jarvis] [JobController] Spinning fort at %@ %@ in %@ seconds", lat, lon, delay);
        CLLocation *lastQuestLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
        [[DeviceState sharedInstance] setLastQuestLocation:lastQuestLocation];
        NSDate *firstWarningDate = [[DeviceState sharedInstance] firstWarningDate];
        NSTimeInterval timeSince = [[NSDate date] timeIntervalSinceDate:firstWarningDate];
        NSNumber *maxWarningTimeRaid = [[Settings sharedInstance] maxWarningTimeRaid];
        if (hasWarning &&
            firstWarningDate != nil &&
            timeSince >= [maxWarningTimeRaid intValue] &&
            [[Settings sharedInstance] enableAccountManager]) {
            NSLog(@"[Jarvis] [JobController] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
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
        NSLog(@"[Jarvis] [JobController] Scanning prepared");
        
        NSDate *start = [NSDate date];
        NSNumber *delayTemp = delay;
        bool success = false;
        bool locked = true;
        while (locked) {
            usleep(100000);
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
            if (timeIntervalSince >= [delayTemp intValue]) {
                NSNumber *left = @([delayTemp intValue] - timeIntervalSince);
                NSLog(@"[Jarvis] [JobController] Delaying by %@", left);
                // TODO: usleep(UInt32(min(10.0, left) * 100000.0));
                continue;
            }
            //self.lock.lock();
            NSNumber *raidMaxTime = [[Settings sharedInstance] raidMaxTime];
            if (timeIntervalSince >= ([raidMaxTime intValue] + [delayTemp intValue])) {
                locked = false;
                [[DeviceState sharedInstance] setWaitForData:false];
                NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
                [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
                NSLog(@"[Jarvis] [JobController] Pokestop loading timed out...");
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
                    NSLog(@"[Jarvis] [JobController] Pokestop loaded after %f", [[NSDate date] timeIntervalSinceDate:start]);
                    [NSThread sleepForTimeInterval:1];
                }
            }
            //self.lock.unlock();
        }
        
        if (success) {
            NSLog(@"[Jarvis] [JobController] Spinning Pokestop");
            NSDate *lastDeployTime = [[DeviceState sharedInstance] lastDeployTime];
            NSNumber *luckyEggsCount = [[DeviceState sharedInstance] luckyEggsCount];
            NSNumber *spinCount = [[DeviceState sharedInstance] spinCount];
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:lastDeployTime];
            if (([luckyEggsCount intValue] >= 1 && timeIntervalSince >= 2000) ||
                ([spinCount intValue] >= 400 && [[[Device sharedInstance] level] intValue] >= 20)) {
                [Jarvis__ getToMainScreen];
                NSLog(@"[Jarvis] [JobController] Clearing Items for UQ");
                if ([Jarvis__ eggDeploy]) {
                    [[DeviceState sharedInstance] setLastDeployTime:[NSDate date]];
                    [[DeviceState sharedInstance] setLuckyEggsCount:[Utils decrementInt:luckyEggsCount]];
                } else {
                    [[DeviceState sharedInstance] setLuckyEggsCount:0];
                }
                [[DeviceState sharedInstance] setSpinCount:0];
                [[DeviceState sharedInstance] setUltraQuestSpin:true];
                [NSThread sleepForTimeInterval:1];
                NSNumber *attempts = @0;
                NSNumber *sleepUsleep = @200000; // 200ms
                while ([[NSDate date] timeIntervalSinceDate:start] < 15.0 + [delay intValue]) {
                    //self.lock.lock();
                    if (![[DeviceState sharedInstance] gotItems]) {
                        //self.lock.unlock();
                        if ([attempts intValue] % 5 == 0) {
                            NSLog(@"[Jarvis] [JobController] Waiting to spin...");
                        }
                        usleep([sleepUsleep intValue]);
                    } else {
                        //self.lock.unlock();
                        NSLog(@"[Jarvis] [JobController] Successfully spun Pokestop");
                        [[DeviceState sharedInstance] setUltraQuestSpin:false];
                        //_spins = _spins + 1;
                        //sleep(3 * [[Device sharedInstance] delayMultiplier;
                        break;
                    }
                    attempts = [Utils incrementInt:attempts];
                }
                [[DeviceState sharedInstance] setUltraQuestSpin:false];
                if (![[DeviceState sharedInstance] gotItems]) {
                    NSLog(@"[Jarvis] [JobController] Failed to spin Pokestop");
                }
            }
        }
        
    } else {
        NSLog(@"[Jarvis] [JobController] Sleep 3 seconds before skipping...");
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
        NSLog(@"[Jarvis] [JobController] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        [DeviceState logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = data[@"lat"] ?: 0;
    NSNumber *lon = data[@"lon"] ?: 0;
    NSLog(@"[Jarvis] [JobController] Scanning for IV at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    [[DeviceState sharedInstance] setWaitRequiresPokemon:true];
    // REVIEW: Not used - _targetMaxDisance = [[Settings sharedInstance] targetMaxDistance];
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitForData:true];
    // REVIEW: Not used - _encounterDelay = [[Settings sharedInstance] encounterDelay];
    //self.lock.unlock();
    NSLog(@"[Jarvis] [JobController] Scanning prepared");
    
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
            NSLog(@"[Jarvis] [JobController] Raids loading timed out.");
            NSMutableDictionary *raidData = [[NSMutableDictionary alloc] init];
            raidData[@"uuid"] = [[Device sharedInstance] uuid];
            raidData[@"action"] = @"scan_raid";
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
                NSLog(@"[Jarvis] [JobController] Pokemon loaded after %f", timeIntervalSince);
            }
        }
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
    //if (_menuButton) {
    //    _menuButton = false;
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
        NSLog(@"[Jarvis] [JobController] [Jarvis] Received ptcToken, swapping account...");
        [DeviceState logout];
    //}
}

@end
