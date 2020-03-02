//
//  UIC.cpp
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#include "UIC.h"
#include "Device.h"
#include "Settings.h"

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIDevice.h>

#import "../GCD/GCDAsyncSocket.h"
//#import "PTFakeTouch/Headers/PTFakeMetaTouch.h"

#include <string>
#include <sys/utsname.h>
#include <math.h>

using namespace std;

// TODO: Remote config
// TODO: Move device/account specific settings to its own class.
// TODO: PTFakeTouch
// TODO: KIF library
// TODO: StateManager class
// TODO: Pixel checks

static BOOL _firststart = true;
static BOOL _startup = true;

static NSString *_localUrl = @"http://localhost:8080/loc";
static BOOL _started = false;
static CLLocation *_currentLocation;
static BOOL _waitRequiresPokemon = false;
static BOOL _waitForData = false;
//lock = NSLock();
static NSDate *_firstWarningDate;
static NSNumber *_jitterCorner = @0;
static BOOL _gotQuest = false;
static BOOL _gotIV = false;
static NSNumber *_noQuestCount = @0;
static NSNumber *_noEncounterCount = @0;
static NSNumber *_emptyGmoCount = @0;
static NSString *_pokemonEncounterId;
static NSString *_action;
static NSNumber *_encounterDistance = @0.0;
static NSNumber *_encounterDelay = @0.0;
static void* _image; // UIImage
static NSUserDefaults *_defaults = [[NSUserDefaults alloc] init];
static NSString *_ptcToken = [_defaults valueForKey:@"5750bac0-483c-4131-80fd-6b047b2ca7b4"];

// Button Detection
static BOOL _menuButton = false;
static BOOL _menuButton2 = false;
static NSString *_neededButton = @"";
static BOOL _okButton = false;
static BOOL _newPlayerButton = false;
static BOOL _bannedScreen = false;
static BOOL _invalidScreen = false;

static NSNumber *_failedGetJobCount;
static NSNumber *_failedCount;

static NSNumber *_startupLat = @0.0;
static NSNumber *_startupLon = @0.0;
static CLLocation *_startupLocation;
static NSNumber *_lastEncounterLat = @0.0;
static NSNumber *_lastEncounterLon = @0.0;
static NSDate *_lastUpdate;
static BOOL _delayQuest = false;
static BOOL _gotQuestEarly = false;

// Mizu Leveling
static BOOL _isQuestInit = false;

// TODO: UIC properties
static BOOL _newLogIn;
static BOOL _newCreated;
static BOOL _needsLogout;
static NSNumber *_minLevel = @0;
static NSNumber *_maxLevel = @29;
static NSDate *_eggStart;

static NSString *_response_200 = @"HTTP/1.1 200 OK\nContent-Type: text/json; charset=utf-8\n\n";
static NSString *_response_400 = @"HTTP/1.1 400 Bad Request\nContent-Type: text/json; charset=utf-8\n\n";
static NSString *_response_404 = @"HTTP/1.1 404 Not Found\nContent-Type: text/json; charset=utf-8\n\n";

static double _baseHorizontalAccuracy = 200.0; // in meters
static double _baseVerticalAccuracy = 200.0; // in meters

@implementation UIC2

static GCDAsyncSocket *_listenSocket;

-(id)init
{
    NSLog(@"[UIC] init");
    if ((self = [super init]))
    {
    }
    
    return self;
}

-(void *)start
{
    NSLog(@"[UIC] start");
    NSLog(@"-----------------------------");
    NSLog(@"[UIC] Device Uuid: %@", [[Device sharedInstance] uuid]);
    NSLog(@"[UIC] Device Model: %@", [[Device sharedInstance] model]);
    NSLog(@"[UIC] Device OS: %@", [[Device sharedInstance] osName]);
    NSLog(@"[UIC] Device OS Version: %@", [[Device sharedInstance] osVersion]);
    NSLog(@"-----------------------------");
    NSLog(@"[UIC] Loading UIC settings...");
    [[Settings sharedInstance] config];
    
    bool started = false;
    NSNumber *startTryCount = @1;
    // Try to start the HTTP listener, attempt 5 times on failure.
    while (!started) {
        @try {
            [self startListener];
        } @catch(id exception) {
            if ([startTryCount intValue] > 5) {
                NSLog(@"[UIC] Fatal error, failed to start server: %@. Try (%@/5)", exception, startTryCount);
                
                NSLog(@"[UIC] Failed to start server: %@. Try (%@/5). Trying again in 5 seconds.", exception, startTryCount);
                startTryCount = [self incrementInt:startTryCount];
                [NSThread sleepForTimeInterval:5];
            }
        }
    }

    // Heatbeat loop
    bool heatbeatRunning = false;
    NSLog(@"[UIC] Starting heatbeat dispatch queue...");
    dispatch_queue_t heatbeatQueue = dispatch_queue_create("heatbeat_queue", NULL);
    dispatch_async(heatbeatQueue, ^{
        NSDictionary *data = @{
            @"uuid": [[Device sharedInstance] uuid],
            @"username": [[Device sharedInstance] username],
            @"type": @"heatbeat"
        };
        [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:data blocking:false completion:^(NSDictionary *result) {}];
        while (heatbeatRunning) {
            // Check if time since last checking was within 2 minutes, if not reboot device.
            [NSThread sleepForTimeInterval:15];
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:_lastUpdate];
            if (timeIntervalSince >= 120) {
                NSLog(@"[UIC][Jarvis] HTTP SERVER DIED. Restarting...");
                [self restart];
            } else {
                NSLog(@"[UIC] Last data %f We Good", timeIntervalSince);
            }
        }
        
        // Force stop HTTP listener to prevent binding issues.
        NSLog(@"[UIC] Force-stopping HTTP server.");
        [_listenSocket disconnect]; // TODO: Check for close/stop method or if disconnect is correct.
    });
    //dispatch_release(heatbeatQueue);
    
    [self startUicLoop];
    
    return 0;
}

-(void *)startListener
{
    NSLog(@"[UIC] startListener");
    _listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    NSNumber *port = [[Settings sharedInstance] port];
    if (![_listenSocket acceptOnPort:[port intValue] error:&error]) {
        NSLog(@"[UIC] Failed to start webserver listener on port %@:\r\nError:%@", port, error);
    }
    NSLog(@"[UIC] Listening at localhost on port %@", port);
    return 0;
}

-(void *)startUicLoop {
    NSLog(@"[UIC] startUicLoop");
    _eggStart = [[NSDate date] initWithTimeInterval:-1860 sinceDate:[NSDate date]];
    // Init AI
    //initJarvis();
    
    NSLog(@"[UIC] Running on %@ delay set to %@",
          [[Device sharedInstance] model],
          [[Device sharedInstance] multiplier]
    );
    [self loginStateHandler];
    
    return 0;
}

-(void *)loginStateHandler {
    dispatch_queue_t loginStateQueue = dispatch_queue_create("login_state_queue", NULL);
    dispatch_async(loginStateQueue, ^{
        NSNumber *startupCount = 0;
        while (_startup) {
            if (!_firststart) {
                NSLog(@"[UIC][Jarvis] App still in startup...");
                while (!_menuButton) {
                    _newPlayerButton = [self clickButton:@"NewPlayerButton"];
                    if (_newPlayerButton) {
                        [_defaults removeObjectForKey:@"5750bac0-483c-4131-80fd-6b047b2ca7b4"];
                        _newPlayerButton = false;
                        NSLog(@"[UIC][Jarvis] Started at Login Screen");
                        [NSThread sleepForTimeInterval:1];
                        bool ptcButton = false;
                        NSNumber *ptcTryCount = 0;
                        while (!ptcButton) {
                            ptcButton = [self clickButton:@"TrainerClubButton"];
                            ptcTryCount = [self incrementInt:ptcTryCount];
                            if ([ptcTryCount intValue] > 10) {
                                _newPlayerButton = [self clickButton:@"NewPlayerButton"];
                                ptcTryCount = 0;
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
                        NSLog(@"[UIC][Jarvis] Account banned, switching accounts.");
                        NSDictionary *data = @{
                            @"uuid": [[Device sharedInstance] uuid],
                            @"username": [[Device sharedInstance] username],
                            @"type": @"account_banned"
                        };
                        [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:data blocking:true completion:^(NSDictionary *result) {}];
                        [self logout];
                    }
                    
                    _invalidScreen = [self findButton:@"WrongUser"];
                    if (_invalidScreen) {
                        _invalidScreen = false;
                        NSLog(@"[UIC][Jarvis] Wrong username, switching accounts.");
                        NSDictionary *data = @{
                            @"uuid": [[Device sharedInstance] uuid],
                            @"username": [[Device sharedInstance] username],
                            @"type": @"account_banned" // TODO: Uhhh should be account_invalid_credentials no?
                        };
                        [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:data blocking:true completion:^(NSDictionary *result) {}];
                        [self logout];
                    }
                    
                    _neededButton = [self getMenuButton];
                    if ([_neededButton isEqualToString:@"DifferentAccountButton"]) {
                        NSDictionary *data = @{
                            @"uuid": [[Device sharedInstance] uuid],
                            @"username": [[Device sharedInstance] username],
                            @"type": @"account_invalid_credentials"
                        };
                        [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:data blocking:true completion:^(NSDictionary *result) {}];
                        [self logout];
                    }
                    
                    if ([_neededButton isEqualToString:@"MenuButton"]) {
                        _menuButton = true;
                    }
                    
                    [NSThread sleepForTimeInterval:5];
                    if ([startupCount intValue] > 10) {
                        NSLog(@"");
                        [self logout];
                    }
                    startupCount = [self incrementInt:startupCount];
                }
                
                [NSThread sleepForTimeInterval:1];
                NSDictionary *dictPtcToken = @{
                };
                [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:dictPtcToken blocking:true completion:^(NSDictionary *result) {}];
                NSLog(@"");
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

-(void *)gameStateHandler {
    // TODO: qos: background dispatch
    dispatch_queue_t gameStateQueue = dispatch_queue_create("game_state_queue", NULL);
    dispatch_async(gameStateQueue, ^{
        bool hasWarning = false;
        _failedGetJobCount = 0;
        _failedCount = 0;
        _emptyGmoCount = 0;
        _noEncounterCount = 0;
        _noQuestCount = 0;
        
        NSDictionary *initData = @{
            @"uuid": [[Device sharedInstance] uuid],
            @"username": [[Device sharedInstance] username],
            @"type": @"init"
        };
        [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:initData blocking:true completion:^(NSDictionary *result) {
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
                _firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
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
            NSDictionary *getAccountData = @{
                @"uuid": [[Device sharedInstance] uuid],
                @"username": [[Device sharedInstance] username],
                @"min_level": _minLevel,
                @"max_level": _maxLevel,
                @"type": @"get_account"
            };
            [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:getAccountData blocking:true completion:^(NSDictionary *result) {
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
                        _startupLocation = [self createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                    } else if ([lastLat doubleValue] != 0.0 && [lastLon doubleValue] != 0.0) {
                        _startupLocation = [self createCoordinate:[lastLat doubleValue] lon:[lastLon doubleValue]];
                    } else {
                        _startupLocation = [self createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                    }
                    _currentLocation = _startupLocation;
                    NSLog(@"[UIC] StartupLocation: %@", _startupLocation);
                    NSNumber *firstWarningTimestamp = [data objectForKey:@"first_warning_timestamp"];
                    if (firstWarningTimestamp != nil) {
                        _firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                    }
                } else {
                    NSLog(@"[UIC] Failed to get account and not logged in.");
                    _minLevel = @1; // Never set to 0 until we can complete tutorials.
                    _maxLevel = @29;
                    [NSThread sleepForTimeInterval:1];
                    [_defaults removeObjectForKey:@"60b01025-clea-422c-9b0e-d70bf489de7f"];
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
                    _currentLocation = _startupLocation;
                    //self.lock.unlock();
                    [self logout];
                }
                NSDictionary *getJobData = @{
                    @"uuid": [[Device sharedInstance] uuid],
                    @"username": [[Device sharedInstance] username],
                    @"type": @"get_job"
                };
                [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:getJobData blocking:true completion:^(NSDictionary *result) {
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
                            _minLevel = minLevel;
                            _maxLevel = maxLevel;
                            NSNumber *currentLevel = [[Device sharedInstance] level];
                            if (currentLevel != 0 && (currentLevel < minLevel || currentLevel > maxLevel)) {
                                NSLog(@"[UIC] Account is outside min/max level. Current: %@ Min/Max: %@/%@. Logging out!", currentLevel, minLevel, maxLevel);
                                //self.lock.lock();
                                _currentLocation = _startupLocation;
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
                            NSLog(@"[UIC][STATUS] Pokemon");
                            [self handlePokemonJob:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_raid"]) {
                            NSLog(@"[UIC][STATUS] Raid");
                            [self handleRaidJob:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"scan_quest"]) {
                            NSLog(@"[UIC][STATUS] Quest/Leveling");
                            [self handleQuestJob:data hasWarning:hasWarning];
                        } else if ([action isEqualToString:@"switch_account"]) {
                            NSLog(@"[UIC][STATUS] Switching Accounts");
                            [[Device sharedInstance] setUsername:nil];
                            [[Device sharedInstance] setIsLoggedIn:false];
                            _isQuestInit = false;
                            // TODO: UserDefaults.synchronize
                            [self logout];
                        } else if ([action isEqualToString:@"scan_iv"]) {
      
                        } else if ([action isEqualToString:@"gather_token"]) {
                            NSLog(@"[UIC][STATUS] Token");
                            if (_menuButton) {
                                _menuButton = false;
                                NSDictionary *tokenData = @{
                                    @"uuid": [[Device sharedInstance] uuid],
                                    @"username": [[Device sharedInstance] username],
                                    @"ptcToken": _ptcToken,
                                    @"type": @"ptcToken"
                                };
                                [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:tokenData blocking:true completion:^(NSDictionary *result) {}];
                                NSLog(@"[UIC][Jarvis] Received ptcToken, swapping account...");
                                [self logout];
                            }
      
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

-(void)handleQuestJob:(NSDictionary *)data hasWarning:(BOOL)hasWarning {
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
    
    // TODO: EggDeploy
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
        NSDictionary *questData = @{
            @"uuid": [[Device sharedInstance] uuid],
            @"action": _action,
            @"lat": lat,
            @"lon": lon,
            @"type": @"job_failed"
        };
        [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:questData blocking:true completion:^(NSDictionary *result) {}];
        //self.lock.lock();
        _currentLocation = _startupLocation;
        //self.lock.unlock();
        [self logout];
    }
    
    _newCreated = false;
    
    //self.lock.lock();
    _currentLocation = [self createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
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
            _failedCount = [self incrementInt:_failedCount];
            NSLog(@"[UIC] Pokestop loading timed out.");
            // TODO: Pass 'action' to method, don't use global _action incase of race condition.
            NSDictionary *failedData = @{
                @"uuid": [[Device sharedInstance] uuid],
                @"action": _action,
                @"lat": lat,
                @"lon": lon,
                @"type": @"job_failed"
            };
            [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:failedData blocking:true completion:^(NSDictionary *result) {}];
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
            _noQuestCount = [self incrementInt:_noQuestCount];
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
                attempts = [self incrementInt:attempts];
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

-(void)handleRaidJob:(NSDictionary *)data hasWarning:(BOOL)hasWarning {
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
    _currentLocation = [self createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
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
            _failedCount = [self incrementInt:_failedCount];
            NSLog(@"[UIC] Raids loading timed out.");
            NSDictionary *raidData = @{
                @"uuid": [[Device sharedInstance] uuid],
                @"action": @"scan_raid",
                @"lat": lat,
                @"lon": lon,
                @"type": @"job_failed"
            };
            [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:raidData blocking:true completion:^(NSDictionary *result) {}];
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

-(void)handlePokemonJob:(NSDictionary *)data hasWarning:(BOOL)hasWarning {
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
    _currentLocation = [self createCoordinate:[lat doubleValue] lon:[lon doubleValue]];
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
            _failedCount = [self incrementInt:_failedCount];
            NSLog(@"[UIC] Pokemon loading timed out.");
            NSDictionary *failedData = @{
                @"uuid": [[Device sharedInstance] uuid],
                @"username": [[Device sharedInstance] username],
                @"action": _action,// TODO: @"scan_pokemon",
                @"lat": lat,
                @"lon": lon,
                @"type": @"job_failed"
            };
            [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:failedData blocking:true completion:^(NSDictionary *result) {}];
        }
    }
}

#pragma GCDAsyncSocket

-(void)socket:(GCDAsyncSocket *)sender didAcceptNewSocket:(nonnull GCDAsyncSocket *)newSocket
{
    // The "sender" parameter is the listenSocket we created.
    // The "newSocket" is a new instance of GCDAsyncSocket.
    // It represents the accepted incoming client connection.
    
    //NSLog(@"[UIC] New connection at %@", [newSocket connectedHost]);
    NSString *host = [newSocket connectedHost];
    UInt16 port = [newSocket connectedPort];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"[UIC] Accepted client %@:%hu", host, port);
        }
    });
    
    [self sendData:newSocket data:_response_200];
    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:1];
}

-(void)socket:(GCDAsyncSocket *)sender didReadData:(nonnull NSData *)data withTag:(long)tag
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
            NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
            if (msg) {
                NSLog(@"[UIC] Received data: %@", msg);
                NSArray *split = [msg componentsSeparatedByString:@" "];
                if ([split count] == 3) {
                    NSString *method = split[0];
                    NSString *query = split[1];
                    NSString *httpProtocol = split[2];
                    if (([method isEqualToString:@"GET"] || [method isEqualToString:@"POST"])
                    && [[httpProtocol substringWithRange:NSMakeRange(0, 4)] isEqualToString:@"HTTP"]) /*TODO: Check against list of valid HTTP protocols*/ {
                        NSString *response = _response_404;
                        if ([query hasPrefix:@"/data"]) {
                            NSArray *querySplit = [query componentsSeparatedByString:@"?"];
                            NSDictionary *params = [self parseUrlQueryParameters:querySplit[1]];
                            response = [self handleDataRequest:params];
                        } else if ([query hasPrefix:@"/loc"]) {
                            NSArray *querySplit = [query componentsSeparatedByString:@"?"];
                            NSDictionary *params = [self parseUrlQueryParameters:querySplit[1]];
                            response = [self handleLocationRequest:params];
                        } else {
                            NSLog(@"[UIC] Invalid request endpoint.");
                        }
                        [sender writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
                    }
                }
            } else {
                NSLog(@"[UIC] Error converting received data into UTF-8 String");
            }
        }
    });
}

#pragma HTTP Listener

-(void)sendData:(GCDAsyncSocket *)socket data:(NSString *)data
{
    NSData *msg = [data dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"[UIC] Sending data: %@", data);
    [socket writeData:msg withTimeout:-1 tag:1];
}

-(NSString *)handleLocationRequest:(NSMutableDictionary *)params {
    NSMutableDictionary *responseData = [[NSMutableDictionary alloc] init];
    //self.lock.lock
    CLLocation *currentLoc = _currentLocation;
    if (currentLoc != nil) {
        if (_waitRequiresPokemon) {
            //self.lock.unlock
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
            [responseData setObject:currentLat forKey:@"latitude"];
            [responseData setObject:currentLon forKey:@"longitude"];
            [responseData setObject:currentLon forKey:@"lat"];
            [responseData setObject:currentLon forKey:@"lng"];

            //"scan_iv", "scan_pokemon"
            if ([[[Device sharedInstance] level] intValue] >= 30) {
                [responseData setObject:@[@"pokemon"] forKey:@"actions"];
            } else {
                [responseData setObject:@[] forKey:@"actions"];
            }
        } else {
            // raids, quests
            //self.lock.unlock
            NSNumber *currentLat = [NSNumber numberWithDouble:currentLoc.coordinate.latitude];
            NSNumber *currentLon = [NSNumber numberWithDouble:currentLoc.coordinate.longitude];
            [responseData setObject:currentLat forKey:@"latitude"];
            [responseData setObject:currentLon forKey:@"longitude"];
            [responseData setObject:currentLon forKey:@"lat"];
            [responseData setObject:currentLon forKey:@"lng"];
            
            bool ultraQuests = [[Settings sharedInstance] ultraQuests];
            if (ultraQuests && [_action isEqualToString:@"scan_quest"] && _delayQuest) {
                // Auto-spinning should only happen when ultraQuests is
                // set and the instance is scan_quest type
                if ([[[Device sharedInstance] level] intValue] >= 30) {
                    [responseData setObject:@[@"pokemon", @"pokestop"] forKey:@"actions"];
                } else {
                    [responseData setObject:@[@"pokestop"] forKey:@"actions"];
                }
            } else if ([_action isEqualToString:@"leveling"]) {
                [responseData setObject:@[@"pokestop"] forKey:@"actions"];
            } else if ([_action isEqualToString:@"scan_raid"]) {
                // Raid instances do not need IV encounters, Use scan_pokemon
                // type if you want to encounter while scanning raids.
                [responseData setObject:@[] forKey:@"actions"];
            }
        }
    }
    
    // TODO: Serialize dict
    // response: "Content-Type" = "application/json";
    
    NSString *response = [NSString stringWithFormat:@"%@\r\n%@", _response_200, responseData];
    return response;
}

-(NSString *)handleDataRequest:(NSMutableDictionary *)params {
    _lastUpdate = [NSDate date];
    CLLocation *currentLoc = [self createCoordinate:_currentLocation.coordinate.latitude lon: _currentLocation.coordinate.longitude];
    //NSNumber *targetMaxDistance = _targetMaxDistance;
    NSString *pokemonEncounterId = _pokemonEncounterId;

    if (_currentLocation == nil) {
        // TODO: return _response_400;
    }
    [params setObject:@(currentLoc.coordinate.latitude) forKey:@"lat_target"];
    [params setObject:@(currentLoc.coordinate.longitude) forKey:@"lon_target"];
    [params setObject:[[Settings sharedInstance] targetMaxDistance] forKey:@"target_max_distance"];
    [params setObject:[[Device sharedInstance] username] ?: @"" forKey:@"username"];
    [params setObject:pokemonEncounterId ?: @"" forKey:@"pokemon_encounter_id"];
    [params setObject:[[Device sharedInstance] uuid] forKey:@"uuid"];
    [params setObject:_ptcToken ?: @"" forKey:@"ptcToken"];

    NSString *url = [[Settings sharedInstance] backendRawUrl];
    [self postRequest:url dict:params blocking:false completion:^(NSDictionary *result) {
        NSDictionary *data = [result objectForKey:@"data"];
        
        // TODO: Check if works, might need to use objectForKey instead
        bool inArea = [data objectForKey:@"in_area"] ?: false;
        NSNumber *level = [data objectForKey:@"level"] ?: @0;
        NSNumber *nearby = [data objectForKey:@"nearby"] ?: @0;
        NSNumber *wild = [data objectForKey:@"wild"] ?: @0;
        NSNumber *quests = [data objectForKey:@"quests"] ?: @0;
        NSNumber *encounters = [data objectForKey:@"encounters"] ?: @0;
        NSNumber *pokemonLat = [data objectForKey:@"pokemon_lat"] ?: @0.0;
        NSNumber *pokemonLon = [data objectForKey:@"pokemon_lon"] ?: @0.0;
        NSString *pokemonEncounterIdResult = [data objectForKey:@"pokemon_encounter_id"];
        NSNumber *targetLat = [data objectForKey:@"target_lat"] ?: @0.0;
        NSNumber *targetLon = [data objectForKey:@"target_lon"] ?: @0.0;
        bool onlyEmptyGmos = [data objectForKey:@"only_empty_gmos"] ?: @true;
        bool onlyInvalidGmos = [data objectForKey:@"only_invalid_gmos"] ?: false;
        bool containsGmo = [data objectForKey:@"contains_gmos"] ?: @true;
        
        NSNumber *pokemonFoundCount = [NSNumber numberWithFloat:([wild intValue] + [nearby intValue])];
        [[Device sharedInstance] setLevel:level];
        NSString *toPrint;
        
        //self.lock.lock();
        NSNumber *diffLat = @([[NSNumber numberWithDouble:currentLoc.coordinate.latitude] doubleValue] - [targetLat doubleValue]);
        NSNumber *diffLon = @([[NSNumber numberWithDouble:currentLoc.coordinate.longitude] doubleValue] - [targetLon doubleValue]);
        
        // TODO: MIZU tut stuff
        
        if (onlyInvalidGmos) {
            _waitForData = false;
            toPrint = @"[UIC] Got GMO but it was malformed. Skipping.";
        } else if (containsGmo) {
            if (inArea && [diffLat doubleValue] < 0.0001 && [diffLon doubleValue] < 0.0001) {
                _emptyGmoCount = 0;
                if (_pokemonEncounterId != nil) {
                    if ([pokemonFoundCount intValue] > 0) {
                        if (pokemonLat != 0 && pokemonLon != 0 && _pokemonEncounterId == pokemonEncounterIdResult) {
                            _waitRequiresPokemon = false;
                            CLLocation *oldLocation = _currentLocation;
                            _currentLocation = [self createCoordinate:[pokemonLat doubleValue] lon:[pokemonLon doubleValue]];
                            CLLocation *newLocation = _currentLocation;
                            _encounterDistance = [NSNumber numberWithDouble:[newLocation distanceFromLocation:oldLocation]];
                            _pokemonEncounterId = nil;
                            _waitForData = false;
                            toPrint = @"[UIC] Got Data and found Pokemon";
                        } else {
                            toPrint = @"[UIC] Got Data but did not find Pokemon";
                        }
                    } else {
                        toPrint = @"[UIC] Got Data without Pokemon";
                    }
                } else if (_waitRequiresPokemon) {
                    if ([pokemonFoundCount intValue] > 0) {
                        toPrint = @"[UIC] Got Data with Pokemon";
                        _waitForData = false;
                    } else {
                        toPrint = @"[UIC] Got Data without Pokemon";
                    }
                } else {
                    toPrint = @"[UIC] Got Data";
                    _waitForData = false;
                }
            } else if (onlyEmptyGmos && !_startup) {
                _emptyGmoCount = [self incrementInt:_emptyGmoCount];
                toPrint = @"[UIC] Got Empty Data";
            } else {
                _emptyGmoCount = 0;
                toPrint = @"[UIC] Got Data outside Target-Area";
            }
        } else {
            toPrint = @"[UIC] Got Data without GMO";
        }

        if (!_gotQuest && quests != 0) {
            _gotQuest = true;
            _gotQuestEarly = true;
        }
        
        if (!_gotIV && encounters != 0) {
            _gotIV = true;
        }
        
        NSLog(@"[UIC] Handle data response: %@", toPrint);
    }];
    NSString *response = [NSString stringWithFormat:@"%@\r\n%@", _response_200, params];
    return response;
}

#pragma App Management

-(void *)restart
{
    NSLog(@"[UIC][Jarvis] Restarting...");
    while (true) {
        // TODO: UIControl().sendAction(#selector(NSXPCConnection.invalidate) to:UIApplication.shared for:nil);
        [NSThread sleepForTimeInterval:2];
    }
}

-(void *)logout
{
    [[Device sharedInstance] setIsLoggedIn:false];
    //_action = nil;
    _delayQuest = false;
    NSDictionary *dict = @{
        @"uuid": [[Device sharedInstance] uuid],
        @"username": [[Device sharedInstance] username],
        @"level": [[Device sharedInstance] level],
        @"type": @"logged_out"
    };
    [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:dict blocking:true completion:nil];
    [[Device sharedInstance] setUsername:nil];
    [[Device sharedInstance] setPassword:nil];
    [NSThread sleepForTimeInterval:0.5];
    if ([[Device sharedInstance] username] == nil &&
        [[Settings sharedInstance] enableAccountManager]) {
        // TODO: Check if this should be empty?
        NSDictionary *payload = @{
            @"uuid": [[Device sharedInstance] uuid],
            @"username": [[Device sharedInstance] username],
            @"min_level": _minLevel,
            @"max_level": _maxLevel,
            @"type": @"get_account"
        };
        [self postRequest:[[Settings sharedInstance] backendControllerUrl]  dict:payload blocking:true completion:^(NSDictionary *result) {
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
                    _startupLocation = [self createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                } else if (![lastLat isEqualToNumber:@0.0] && ![lastLon isEqualToNumber:@0.0]) {
                    _startupLocation = [self createCoordinate:[lastLat doubleValue] lon:[lastLon doubleValue]];
                } else {
                    _startupLocation = [self createCoordinate:[startLat doubleValue] lon:[startLon doubleValue]];
                }
            
                _currentLocation = _startupLocation;
                NSLog(@"[UIC] StartupLocation: %@", _startupLocation);
                NSNumber *firstWarningTimestamp = [data objectForKey:@"first_warning_timestamp"];
                if (firstWarningTimestamp != nil) {
                    _firstWarningDate = [NSDate dateWithTimeIntervalSince1970:[firstWarningTimestamp doubleValue]];
                }
                if (username != nil && ptcToken != nil && ![ptcToken isEqualToString:@""]) {
                    NSLog(@"[UIC] Got token %@ level %@ from backend.", ptcToken, level);
                    NSLog(@"[UIC] Got account %@ level %@ from backend.", username, level);
                    [[Device sharedInstance] setUsername:username];
                    [[Device sharedInstance] setPassword:password];
                    [[Device sharedInstance] setPtcToken:ptcToken];
                    [[Device sharedInstance] setLevel:level];
                    [[Device sharedInstance] setIsLoggedIn:true];
                    [_defaults setValue:ptcToken forKey:@"5750bac0-483c-4131-80fd-6b047b2ca7b4"];
                    [_defaults synchronize];
                } else {
                    NSLog(@"[UIC][Jarvis] Failed to get account with token. Restarting for normal login.");
                    [_defaults synchronize];
                    [_defaults removeObjectForKey:@"60b01025-c1ea-422c-9b0e-d70bf489de7f"];
                    [[Device sharedInstance] setUsername:username];
                    [[Device sharedInstance] setPassword:password];
                    [[Device sharedInstance] setPtcToken:ptcToken];
                    [[Device sharedInstance] setLevel:level];
                    [[Device sharedInstance] setIsLoggedIn:false];
                    [[Device sharedInstance] setShouldExit:true];
                }
            } else {
                NSLog(@"[UIC][Jarvis] Failed to get account, restarting.");
                [NSThread sleepForTimeInterval:1];
                _minLevel = @0; // Never set to 0 until we can do tutorials.
                _maxLevel = @29;
                [_defaults synchronize];
                [_defaults removeObjectForKey:@"60b01025-clea-422c-9b0e-d70bf489de7f"];
                [NSThread sleepForTimeInterval:5];
                [[Device sharedInstance] setIsLoggedIn:false];
                [self restart];
            }
        }];
    }
    
    [NSThread sleepForTimeInterval:1];
    [self restart];
    
    return 0;
}

#pragma Utilities

-(void)postRequest:(NSString *)urlString dict:(NSDictionary *)data blocking:(BOOL)blocking completion:(void (^)(NSDictionary* result))completion
{
    BOOL done = false;
    NSDictionary *resultDict;
    
    // Create the URLSession on the default configuration
    NSURLSessionConfiguration *defaultSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:defaultSessionConfiguration];

    // Setup the request with URL
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];

    // Convert POST string parameters to data using UTF8 Encoding
    //NSString *postParams = @"api_key=APIKEY&email=example@example.com&password=password";
    //NSData *postData = [postParams dataUsingEncoding:NSUTF8StringEncoding];

    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&error];
    [urlRequest setHTTPBody:postData];
    [urlRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-Length"];

    //if ([[Settings uuid] isEqualToString:@"test"]) {
    //    [urlRequest addValue:@"Bearer \(token)" forHTTPHeaderField:@"Authorization");
    //}
    
    // Convert POST string parameters to data using UTF8 Encoding
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    // Create dataTask
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"[UIC] postRequest response: %@", responseData);
        if (data != nil) { // TODO: Check if json parsed
            NSError *jsonError;
            NSDictionary *resultJson = [NSJSONSerialization JSONObjectWithData:data
                                                                       options:NSJSONReadingMutableContainers
                                                                         error:&jsonError];
            // TODO: Variable is not assignable (missing __block type specifier) resultDict = resultJson;
            if (!blocking) {
                completion(resultJson);//resultDict);
            }
        } else {
            if (!blocking) {
                completion(nil);
            }
        }
        // TODO: Variable is not assignable (missing __block type specifier) done = true;
    }];

    // Fire the request
    [dataTask resume];
    if (blocking) {
        while (!done) {
            usleep(1000);
        }
        completion(resultDict);
    }
}

-(NSMutableDictionary *)parseUrlQueryParameters:(NSString *)queryParameters
{
    NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
    NSArray *components = [queryParameters componentsSeparatedByString:@"&"];
    for (NSString *pair in components)
    {
        NSArray *pairComponents = [pair componentsSeparatedByString:@"="];
        NSString *key = [[pairComponents firstObject] stringByRemovingPercentEncoding];
        NSString *value = [[pairComponents lastObject] stringByRemovingPercentEncoding];

        [queryStringDictionary setObject:value forKey:key];
    }
    return queryStringDictionary;
}

-(CLLocation *)createCoordinate:(double)lat lon:(double)lon
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lon);
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                  altitude:-1
                        horizontalAccuracy:_baseHorizontalAccuracy
                          verticalAccuracy:_baseVerticalAccuracy
                                 timestamp:[NSDate date]];
    return location;
}

-(NSNumber *)incrementInt:(NSNumber *)value
{
    return [NSNumber numberWithInt:[value intValue] + 1];
}

@end
