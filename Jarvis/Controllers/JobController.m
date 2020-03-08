//
//  JobController.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "JobController.h"

@implementation JobController

#pragma mark Job Handlers

-(void)handlePokemonJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    if (hasWarning && [[Settings sharedInstance] enableAccountManager]) {
        NSLog(@"[UIC] Account has a warning and tried to scan for Pokemon. Logging out!");
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        //[self logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = [data objectForKey:@"lat"];
    NSNumber *lon = [data objectForKey:@"lon"];
    NSLog(@"[UIC] Scanning for Pokemon at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    [[DeviceState sharedInstance] setWaitRequiresPokemon:true];
    [[DeviceState sharedInstance] setPokemonEncounterId:nil];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]]];
    [[DeviceState sharedInstance] setWaitForData:true];
    //self.lock.unlock();
    NSLog(@"[UIC] Scanning prepared");
    
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
            NSLog(@"[UIC] Pokemon loading timed out.");
            NSMutableDictionary *failedData = [[NSMutableDictionary alloc] init];
            failedData[@"uuid"] = [[Device sharedInstance] uuid];
            failedData[@"username"] = [[Device sharedInstance] username];
            failedData[@"action"] = action;// TODO: @"scan_pokemon",
            failedData[@"lat"] = lat;
            failedData[@"lon"] = lon;
            failedData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:failedData blocking:true completion:^(NSDictionary *result) {}];
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
        NSLog(@"[UIC] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        //[self logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = [data objectForKey:@"lat"] ?: 0;
    NSNumber *lon = [data objectForKey:@"lon"] ?: 0;
    NSLog(@"[UIC] Scanning for Raid at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
    //_targetMaxDistance = [[Settings sharedInstance] targetMaxDistance];
    [[DeviceState sharedInstance] setWaitForData:true];
    //self.lock.unlock();
    NSLog(@"[UIC] Scanning prepared.");
    
    BOOL locked = true;
    NSNumber *raidMaxTime = [[Settings sharedInstance] raidMaxTime];
    while (locked) {
        //self.lock.lock();
        NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:start];
        if (timeIntervalSince >= [raidMaxTime intValue]) {
            locked = false;
            [[DeviceState sharedInstance] setWaitForData:false];
            //_failedCount = [Utils incrementInt:_failedCount];
            NSNumber *failedCount = [[DeviceState sharedInstance] failedCount];
            [[DeviceState sharedInstance] setFailedCount:[Utils incrementInt:failedCount]];
            NSLog(@"[UIC] Raids loading timed out.");
            NSMutableDictionary *raidData = [[NSMutableDictionary alloc] init];
            raidData[@"uuid"] = [[Device sharedInstance] uuid];
            raidData[@"action"] = action;
            raidData[@"lat"] = lat;
            raidData[@"lon"] = lon;
            raidData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:raidData blocking:true completion:^(NSDictionary *result) {}];
        } else {
            locked = [[DeviceState sharedInstance] waitForData];
            if (!locked) {
                //_failedCount = 0;
                [[DeviceState sharedInstance] setFailedCount:0];
                NSLog(@"[UIC] Raids loaded after %f", timeIntervalSince);
            }
        }
        //self.lock.unlock();
    }
}

-(void)handleQuestJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    /*
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
        questData[@"action"] = action;
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
            failedData[@"action"] = action;
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
    */
}

-(void)handleLeveling:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    /*
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
    */
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
        NSLog(@"[UIC] Account has warning and is over maxWarningTimeRaid (%@). Logging out!", maxWarningTimeRaid);
        //self.lock.lock();
        CLLocation *startupLocation = [[DeviceState sharedInstance] startupLocation];
        [[DeviceState sharedInstance] setCurrentLocation:startupLocation];
        //[self logout];
        //self.lock.unlock();
    }
    
    NSNumber *lat = [data objectForKey:@"lat"] ?: 0;
    NSNumber *lon = [data objectForKey:@"lon"] ?: 0;
    NSLog(@"[UIC] Scanning for IV at %@ %@", lat, lon);
    
    NSDate *start = [NSDate date];
    //self.lock.lock();
    [[DeviceState sharedInstance] setWaitRequiresPokemon:true];
    // REVIEW: Not used - _targetMaxDisance = [[Settings sharedInstance] targetMaxDistance];
    CLLocation *currentLocation = [Utils createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
    [[DeviceState sharedInstance] setCurrentLocation:currentLocation];
    [[DeviceState sharedInstance] setWaitForData:true];
    // REVIEW: Not used - _encounterDelay = [[Settings sharedInstance] encounterDelay];
    //self.lock.unlock();
    NSLog(@"[UIC] Scanning prepared");
    
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
            NSLog(@"[UIC] Raids loading timed out.");
            NSMutableDictionary *raidData = [[NSMutableDictionary alloc] init];
            raidData[@"uuid"] = [[Device sharedInstance] uuid];
            raidData[@"action"] = @"scan_raid";
            raidData[@"lat"] = lat;
            raidData[@"lon"] = lon;
            raidData[@"type"] = @"job_failed";
            [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:raidData blocking:true completion:^(NSDictionary *result) {}];
        } else {
            locked = [[DeviceState sharedInstance] waitForData];;
            if (!locked) {
                [[DeviceState sharedInstance] setFailedCount:0];
                NSLog(@"[UIC] Pokemon loaded after %f", timeIntervalSince);
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
    //[self logout];
}

-(void)handleGatherToken:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning
{
    //if (_menuButton) {
    //    _menuButton = false;
        NSMutableDictionary *tokenData = [[NSMutableDictionary alloc] init];
        tokenData[@"uuid"] = [[Device sharedInstance] uuid];
        tokenData[@"username"] = [[Device sharedInstance] username];
        tokenData[@"ptcToken"] = [[DeviceState sharedInstance] ptcToken];
        tokenData[@"type"] = @"ptcToken";
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl] dict:tokenData blocking:true completion:^(NSDictionary *result) {}];
        NSLog(@"[UIC] [Jarvis] Received ptcToken, swapping account...");
    //    [self logout];
    //}
}

@end
