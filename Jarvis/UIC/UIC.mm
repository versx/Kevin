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
//#include <curl/curl.h>

using namespace std;

// TODO: Remote config

static BOOL _firststart = true;
static BOOL _startup = true;

static NSString *_backend = @"http://10.0.1.100:9001";
static NSString *_backendControllerUrl = [_backend stringByAppendingString:@"/controler"];
static NSString *_backendRawUrl = [_backend stringByAppendingString:@"/raw"];
static NSString *_localUrl = @"http://localhost:8080/loc";
static BOOL _started = false;
static CLLocation *_currentLocation;
static BOOL _waitRequiresPokemon = false;
static BOOL _waitForData = false;
//lock = NSLock();
static NSDate *_firstWarningDate;
static NSNumber *_jitterCorner = 0;
static BOOL _gotQuest = false;
static BOOL _gotIV = false;
static NSNumber *_noQuestCount = @0;
static NSNumber *_noEncounterCount = @0;
static NSNumber *_targetMaxDistance = @250.0;
static NSNumber *_emptyGmoCount = @0;
static NSString *_pokemonEncounterId;
static NSString *_action;
static double _encounterDistance = 0.0;
static NSNumber *_encounterDelay = @0.0;
static void* _image; // UIImage
static NSNumber *_level = @0;
static NSString *_ptcToken; // Load from UserDefaults (5750bac0-483c-4131-80fd-6b047b2ca7b4)

// Button Detection
static BOOL _menuButton = false;
static BOOL _menuButton2 = false;
static NSString *_neededButton = @"";
static BOOL _okButton = false;
static BOOL _newPlayerButton = false;
static BOOL _bannedScreen = false;
static BOOL _invalidScreen = false;

static NSNumber *_startupLat = @0.0;
static NSNumber *_startupLon = @0.0;
static CLLocation *_startupLocation;
static NSNumber *_lastEncounterLat = @0.0;
static NSNumber *_lastEncounterLon = @0.0;
static NSDate *_lastUpdate;
static BOOL _delayQuest = false;
static BOOL _gotQuestEarly = false;
static NSString *_friendName = @"";

// TODO: UIC properties
static BOOL _shouldExit;
static NSString *_username;
static NSString *_password;
static BOOL _newLogIn;
static BOOL _isLoggedIn;
static BOOL _newCreated;
static BOOL _needsLogout;
static NSNumber *_minLevel = @0;
static NSNumber *_maxLevel = @(29);

static NSString *_response_200 = @"HTTP/1.1 200 OK\nContent-Type: text/json; charset=utf-8\n\n";
static NSString *_response_400 = @"HTTP/1.1 400 Bad Request\nContent-Type: text/json; charset=utf-8\n\n";
static NSString *_response_404 = @"HTTP/1.1 404 Not Found\nContent-Type: text/json; charset=utf-8\n\n";

static double _baseHorizontalAccuracy = 200.0; // in meters
static double _baseVerticalAccuracy = 200.0; // in meters

@implementation UIC2

static NSDictionary *_uicSettings;
static NSNumber *_port = @(8080);
static GCDAsyncSocket *_listenSocket;

+(NSNumber *)port {
    return _port;
}

+(NSDictionary *)uicSettings {
    return _uicSettings;
}

-(id)init
{
    NSLog(@"[UIC] init");
    if ((self = [super init]))
    {
    }
    
    return self;
}

-(void *)start:(NSNumber *)port
{
    NSLog(@"[UIC] start");
    NSLog(@"-----------------------------");
    NSLog(@"[UIC] Device Uuid: %@", [[Device sharedInstance] uuid]);
    NSLog(@"[UIC] Device Model: %@", [[Device sharedInstance] model]);
    NSLog(@"[UIC] Device OS: %@", [[Device sharedInstance] osName]);
    NSLog(@"[UIC] Device OS Version: %@", [[Device sharedInstance] osVersion]);
    NSLog(@"-----------------------------");
    NSLog(@"[UIC] Loading UIC settings...");
    _uicSettings = [[Settings sharedInstance] config];
    
    _port = port;
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
                startTryCount = [NSNumber numberWithInt:[startTryCount intValue] + 1];
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
            @"username": _username,
            @"type": @"heatbeat"
        };
        [self postRequest:_backendControllerUrl dict:data blocking:false completion:^(NSDictionary *result) {}];
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
    if (![_listenSocket acceptOnPort:[_port intValue] error:&error]) {
        NSLog(@"[UIC] Failed to start webserver listener on port %@:\r\nError:%@", _port, error);
    }
    NSLog(@"[UIC] Listening at localhost on port %@", _port);
    return 0;
}

-(void *)startUicLoop {
    NSLog(@"[UIC] startUicLoop");
    NSDate *eggStart = [NSDate date]; //Date(timeInterval:-1860, since: Date());
    // Init AI
    //initJarvis();
    
    NSLog(@"[UIC] Running on %@ delay set to %@",
          [[Device sharedInstance] model],
          [[Device sharedInstance] multiplier]
    );
    dispatch_queue_t heatbeatQueue = dispatch_queue_create("state_queue", NULL);
    dispatch_async(heatbeatQueue, ^{
        NSNumber *startupCount = 0;
        while (_startup) {
            if (!_firststart) {
                NSLog(@"[UIC][Jarvis] App still in startup...");
                while (!_menuButton) {
                    _newPlayerButton = [self clickButton:@"NewPlayerButton"];
                    if (_newPlayerButton) {
                        NSUserDefaults *defaults = [[NSUserDefaults alloc] init];
                        [defaults removeObjectForKey:@"5750bac0-483c-4131-80fd-6b047b2ca7b4"];
                        _newPlayerButton = false;
                        NSLog(@"[UIC][Jarvis] Started at Login Screen");
                        [NSThread sleepForTimeInterval:1];
                        bool ptcButton = false;
                        NSNumber *ptcTryCount = 0;
                        while (!ptcButton) {
                            ptcButton = [self clickButton:@"TrainerClubButton"];
                            ptcTryCount = [NSNumber numberWithInt:[ptcTryCount intValue] + 1];
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
                            @"username": _username,
                            @"type": @"account_banned"
                        };
                        [self postRequest:_backendControllerUrl dict:data blocking:true completion:^(NSDictionary *result) {}];
                        [self logout];
                    }
                    
                    _invalidScreen = [self findButton:@"WrongUser"];
                    if (_invalidScreen) {
                        _invalidScreen = false;
                        NSLog(@"[UIC][Jarvis] Wrong username, switching accounts.");
                        NSDictionary *data = @{
                            @"uuid": [[Device sharedInstance] uuid],
                            @"username": _username,
                            @"type": @"account_banned" // TODO: Uhhh should be account_invalid_credentials no?
                        };
                        [self postRequest:_backendControllerUrl dict:data blocking:true completion:^(NSDictionary *result) {}];
                        [self logout];
                    }
                    
                    _neededButton = [self getMenuButton];
                    if ([_neededButton isEqualToString:@"DifferentAccountButton"]) {
                        NSDictionary *data = @{
                            @"uuid": [[Device sharedInstance] uuid],
                            @"username": _username,
                            @"type": @"account_invalid_credentials"
                        };
                        [self postRequest:_backendControllerUrl dict:data blocking:true completion:^(NSDictionary *result) {}];
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
                    startupCount = [NSNumber numberWithInt:[startupCount intValue] + 1];
                }
                
                [NSThread sleepForTimeInterval:1];
                NSDictionary *dictPtcToken = @{
                };
                [self postRequest:_backendControllerUrl dict:dictPtcToken blocking:true completion:^(NSDictionary *result) {}];
                NSLog(@"");
                [self clickButton:@"TrackerButton"];
                _startup = false;
            } else {
                [NSThread sleepForTimeInterval:10];
                _firststart = false;
            }
        }
    });
    
    return 0;
}

-(BOOL)clickButton:(NSString *)buttonName
{
    // TODO: Parse button name, check coordinates list, simulate touch.
    return YES;
}

-(BOOL)findButton:(NSString *)buttonName
{
    // TODO: findButton
    return YES;
}

-(NSString *)getMenuButton
{
    return @"";
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
                    && [[httpProtocol substringWithRange:NSMakeRange(0, 4)] isEqualToString:@"HTTP"]) {
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
            NSNumber *jitterValue = [_uicSettings objectForKey:@"jitterValue"]; // TODO: Load from Settings
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
            if ([_level intValue] >= 30) {
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
            
            bool ultraQuests = [_uicSettings objectForKey:@"ultraQuests"] ?: false;
            if (ultraQuests && [_action isEqualToString:@"scan_quest"] && _delayQuest) {
                // Auto-spinning should only happen when ultraQuests is
                // set and the instance is scan_quest type
                if ([_level intValue] >= 30) {
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
    NSNumber *targetMaxDistance = _targetMaxDistance;
    NSString *pokemonEncounterId = _pokemonEncounterId;

    if (_currentLocation == nil) {
        // TODO: return _response_400;
    }
    [params setObject:@(currentLoc.coordinate.latitude) forKey:@"lat_target"];
    [params setObject:@(currentLoc.coordinate.longitude) forKey:@"lon_target"];
    [params setObject:targetMaxDistance forKey:@"target_max_distance"];
    [params setObject:_username ?: @"" forKey:@"username"];
    [params setObject:pokemonEncounterId ?: @"" forKey:@"pokemon_encounter_id"];
    [params setObject:[[Device sharedInstance] uuid] forKey:@"uuid"];
    [params setObject:_ptcToken ?: @"" forKey:@"ptcToken"];

    NSString *url = _backendRawUrl;
    // TODO: Post request
    [self postRequest:url dict:params blocking:false completion:^(NSDictionary *result) {
        NSDictionary *data = [result objectForKey:@"data"];
        
        // TODO: Check if works, might need to use objectForKey instead
        bool inArea = data[@"in_area"];
        NSNumber *level = data[@"level"];// ?? 0;
        NSNumber *nearby = data[@"nearby"];// ?? 0;
        NSNumber *wild = data[@"wild"];// ?? 0;
        NSNumber *quests = data[@"quests"];// ?? 0;
        NSNumber *encounters = data[@"encounters"];// ?? 0;
        NSNumber *pokemonLat = data[@"pokemon_lat"];// ?? 0.0;
        NSNumber *pokemonLon = data[@"pokemon_lon"];// ?? 0.0;
        NSString *pokemonEncounterIdResult = data[@"pokemon_encounter_id"];
        NSNumber *targetLat = data[@"target_lat"];// ?? 0.0;
        NSNumber *targetLon = data[@"target_lon"];// ?? 0.0;
        bool onlyEmptyGmos = data[@"only_empty_gmos"];// ?? true;
        bool onlyInvalidGmos = data[@"only_invalid_gmos"];// ?? false;
        bool containsGmo = data[@"contains_gmos"];// ?? true;
        
        NSNumber *pokemonFoundCount = [NSNumber numberWithFloat:([wild intValue] + [nearby intValue])];
        _level = level;
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
                            _encounterDistance = [newLocation distanceFromLocation:oldLocation];
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
                _emptyGmoCount = [NSNumber numberWithInt:[_emptyGmoCount intValue] + 1];
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

-(void *)restart {
    NSLog(@"[UIC][Jarvis] Restarting...");
    while (true) {
        // TODO: UIControl().sendAction(#selector(NSXPCConnection.invalidate) to:UIApplication.shared for:nil);
        [NSThread sleepForTimeInterval:2];
    }
}

-(void *)logout {
    _isLoggedIn = false;
    //_action = nil;
    _delayQuest = false;
    NSDictionary *dict = @{
        @"uuid": [[Device sharedInstance] uuid],
        @"username": _username,
        @"level": _level,
        @"type": @"logged_out"
    };
    [self postRequest:_backendControllerUrl dict:dict blocking:true completion:nil];
    _username = nil;
    _password = nil;
    [NSThread sleepForTimeInterval:0.5];
    if (_username == nil && [_uicSettings objectForKey:@"enableAccountManager"] ?: false) {
        NSDictionary *payload = @{
        };
        [self postRequest:_backendControllerUrl dict:payload blocking:true completion:^(NSDictionary *result) {
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
                    _username = username;
                    _password = password;
                    _ptcToken = ptcToken;
                    _level = level;
                    _isLoggedIn = true;
                    NSUserDefaults *defaults = [[NSUserDefaults alloc] init];
                    [defaults setValue:ptcToken forKey:@"5750bac0-483c-4131-80fd-6b047b2ca7b4"];
                    [defaults synchronize];
                } else {
                    NSLog(@"[UIC][Jarvis] Failed to get account with token. Restarting for normal login.");
                    NSUserDefaults *defaults = [[NSUserDefaults alloc] init];
                    [defaults synchronize];
                    [defaults removeObjectForKey:@"60b01025-c1ea-422c-9b0e-d70bf489de7f"];
                    _username = username;
                    _password = password;
                    _ptcToken = ptcToken;
                    _level = level;
                    _isLoggedIn = false;
                    _shouldExit = true;
                }
            } else {
                NSLog(@"[UIC][Jarvis] Failed to get account, restarting.");
                [NSThread sleepForTimeInterval:1];
                _minLevel = @0; // Never set to 0 until we can do tutorials.
                _maxLevel = @29;
                NSUserDefaults *defaults = [[NSUserDefaults alloc] init];
                [defaults synchronize];
                [defaults removeObjectForKey:@"60b01025-clea-422c-9b0e-d70bf489de7f"];
                [NSThread sleepForTimeInterval:5];
                _isLoggedIn = false;
                [self restart];
            }
        }];
    }
    
    [NSThread sleepForTimeInterval:1];
    [self restart];
    
    return 0;
}

#pragma Utilities

-(void *)postRequest:(NSString *)urlString dict:(NSDictionary *)data blocking:(BOOL)blocking completion:(void (^)(NSDictionary* result))completion
{
    //BOOL done = false;
    
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
        NSLog(@"[UIC] postRequest response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        // TODO: Serialize to json
        if (data != nil) { // TODO: Check if json parsed
            if (!blocking) {
                //completion(resultDict);
            }
        } else {
            if (!blocking) {
                completion(nil);
            }
        }
        //done = true;
    }];

    // Fire the request
    [dataTask resume];
    /*
    if (blocking) {
        while (!done) {
            usleep(1000);
        }
        completion(resultDict);
    }
    */
    return 0;
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

@end
