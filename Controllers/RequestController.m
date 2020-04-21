//
//  RequestController.m
//  Jarvis++
//
//  Created by versx on 3/29/20.
//

#import "RequestController.h"

@implementation RequestController

static int _jitterCorner;

+(RequestController *)sharedInstance
{
    static RequestController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RequestController alloc] init];
    });
    return sharedInstance;
}

-(id)init
{
    if ((self = [super init])) {
        _jitterCorner = 0;
    }
    return self;
}


#pragma mark Web Request Handlers

/**
 Handle `/loc` web requests.
 */
-(NSString *)handleLocationRequest
{
    NSMutableDictionary *responseData = [[NSMutableDictionary alloc] init];
    CLLocation *currentLoc = [[DeviceState sharedInstance] currentLocation];
    if (currentLoc != nil) {
        if ([[DeviceState sharedInstance] waitRequiresPokemon]) {
            double jitterValue = [[Settings sharedInstance] jitterValue];
            double jitterLat = 0.0;
            double jitterLon = 0.0;
            switch (_jitterCorner) {
                case 0:
                    jitterLat = jitterValue;
                    jitterLon = jitterValue;
                    _jitterCorner = 1;
                    break;
                case 1:
                    jitterLat = -jitterValue;
                    jitterLon = jitterValue;
                    _jitterCorner = 2;
                    break;
                case 2:
                    jitterLat = -jitterValue;
                    jitterLon = -jitterValue;
                    _jitterCorner = 3;
                    break;
                default:
                    jitterLat = jitterValue;
                    jitterLon = -jitterValue;
                    _jitterCorner = 0;
                    break;
            }

            NSNumber *currentLat = @([[NSNumber numberWithDouble:currentLoc.coordinate.latitude] doubleValue] + jitterLat);
            NSNumber *currentLon = @([[NSNumber numberWithDouble:currentLoc.coordinate.longitude] doubleValue] + jitterLon);
            responseData[@"latitude"] = currentLat;
            responseData[@"longitude"] = currentLon;
            responseData[@"lat"] = currentLat;
            responseData[@"lng"] = currentLon;

            //"scan_iv", "scan_pokemon"
            if ([[[Device sharedInstance] level] intValue] >= 30) {
                responseData[@"actions"] = @[@"pokemon"];
            } else {
                responseData[@"actions"] = @[@""];
            }
        } else {
            // raids, quests
            NSNumber *currentLat = [NSNumber numberWithDouble:currentLoc.coordinate.latitude];
            NSNumber *currentLon = [NSNumber numberWithDouble:currentLoc.coordinate.longitude];
            responseData[@"latitude"] = currentLat;
            responseData[@"longitude"] = currentLon;
            responseData[@"lat"] = currentLat;
            responseData[@"lng"] = currentLon;
            
            bool ultraQuests = [[Settings sharedInstance] ultraQuests];
            bool delayQuest = [[DeviceState sharedInstance] delayQuest];
            NSString *action = [[DeviceState sharedInstance] lastAction];
            NSNumber *luckyEggsCount = [[Device sharedInstance] luckyEggsCount];
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
                if ([luckyEggsCount intValue] > 0) {
                    responseData[@"actions"] = @[@"pokestop", @"luckyegg"];
                } else {
                    responseData[@"actions"] = @[@"pokestop"];
                }
            } else if ([action isEqualToString:@"scan_raid"]) {
                // Raid instances do not need IV encounters, Use scan_pokemon
                // type if you want to encounter while scanning raids.
                responseData[@"actions"] = @[@""];
            }
        }
    }

    NSString *response = [Utils toJsonString:responseData withPrettyPrint:false];
    return response;
}

/**
 Handle `/data` web requests.
 */
-(NSString *)handleDataRequest:(NSDictionary *)params
{
    CLLocation *currentLocation = [[DeviceState sharedInstance] currentLocation];
    [[DeviceState sharedInstance] setLastUpdate:[NSDate date]];
    CLLocation *currentLoc = [Utils createCoordinate:currentLocation.coordinate.latitude
                                                 lon:currentLocation.coordinate.longitude];
    NSMutableDictionary *data = [params mutableCopy];
    data[@"lat_target"] = @(currentLoc.coordinate.latitude);
    data[@"lon_target"] = @(currentLoc.coordinate.longitude);
    data[@"target_max_distnace"] = @(DEFAULT_TARGET_MAX_DISTANCE);// TODO: [[Settings sharedInstance] targetMaxDistance];
    data[@"username"] = [[Device sharedInstance] username] ?: @"";
    data[@"pokemon_encounter_id"] = [[DeviceState sharedInstance] pokemonEncounterId] ?: @"";
    data[@"uuid"] = [[Device sharedInstance] uuid];
    data[@"uuid_control"] = [[Device sharedInstance] uuid];
    data[@"ptcToken"] = [[Device sharedInstance] ptcToken] ?: @"";
    [Utils postRequest:[[Settings sharedInstance] backendRawUrl]
                  dict:data
              blocking:false
            completion:^(NSDictionary *result) {
        //syslog(@"[DEBUG] Raw data response: %@", result);
        if (data == nil) {
            syslog(@"[WARN] Raw response null");
            return;
        }
        NSDictionary *data = [result objectForKey:@"data"];
        bool inArea = [data[@"in_area"] boolValue] ?: false;
        NSNumber *level = data[@"level"] ?: @0;
        NSNumber *nearby = data[@"nearby"] ?: @0;
        NSNumber *wild = data[@"wild"] ?: @0;
        NSNumber *quests = data[@"quests"] ?: @0;
        NSNumber *encounters = data[@"encounters"] ?: @0;
        NSNumber *pokemonLat = data[@"pokemon_lat"] ?: @0.0;
        NSNumber *pokemonLon = data[@"pokemon_lon"] ?: @0.0;
        NSString *pokemonEncounterIdResult = data[@"pokemon_encounter_id"];
        NSNumber *targetLat = data[@"lat_target"] ?: @0.0;
        NSNumber *targetLon = data[@"lon_target"] ?: @0.0;
        bool onlyEmptyGmos = [data[@"only_empty_gmos"] boolValue] ?: true;
        bool onlyInvalidGmos = [data[@"only_invalid_gmos"] boolValue] ?: false;
        bool containsGmo = [data[@"contains_gmos"] boolValue] ?: true;
        NSNumber *luckyEggs = data[@"lucky_eggs"] ?: @0;
        NSNumber *items = data[@"items"] ?: @0;
        
        NSNumber *diffLat = @(currentLoc.coordinate.latitude - [targetLat doubleValue]);
        NSNumber *diffLon = @(currentLoc.coordinate.longitude - [targetLon doubleValue]);
        
        // MIZU tut stuff
        //NSString *spinFortId = data[@"spin_fort_id"] ?: @"";
        //NSNumber *spinFortLat = data[@"spin_fort_lat"] ?: @0.0;
        //NSNumber *spinFortLon = data[@"spin_fort_lon"] ?: @0.0;
        if ([level intValue] > 0) {
            if ([[Device sharedInstance] level] != level) {
                NSNumber *oldLevel = [[Device sharedInstance] level];
                syslog(@"[DEBUG] Level changed from %@ to %@", oldLevel, level);
                NSNumber *luckyEggsCount = [[Device sharedInstance] luckyEggsCount];
                if ([oldLevel intValue] > 0) {
                    switch ([level intValue]) {
                        case 9:
                            syslog(@"[DEBUG] Hit level 9 adding 1 lucky egg");
                            [[Device sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount]];
                            break;
                        case 10:
                            syslog(@"[DEBUG] Hit level 10 adding 1 lucky egg");
                            [[Device sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount]];
                            break;
                        case 15:
                            syslog(@"[DEBUG] Hit level 15 adding 1 lucky egg");
                            [[Device sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount]];
                            break;
                        case 20:
                            syslog(@"[DEBUG] Hit level 20 adding 2 lucky eggs");
                            [[Device sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount withAmount:@2]];
                            break;
                        case 25:
                            syslog(@"[DEBUG] Hit level 25 adding 1 lucky egg");
                            [[Device sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount]];
                            break;
                    }
                }
            }
            // If we're provided a `lucky_eggs` from backend, use it.
            if ([luckyEggs intValue] > 0) {
                syslog(@"[DEBUG] Setting lucky egg value from backend: %@", luckyEggs);
                [[Device sharedInstance] setLuckyEggsCount:luckyEggs];
            }
            [[Device sharedInstance] setLevel:level];
        }

        //syslog(@"[DEBUG] [RES1] inArea: %s level: %@ nearby: %@ wild: %@ quests: %@ encounters: %@ plat: %@ plon: %@ encounterResponseId: %@ tarlat: %@ tarlon: %@ emptyGMO: %s invalidGMO: %s containsGMO: %s", (inArea ? "Yes" : "No"), level, nearby, wild, quests, encounters, pokemonLat, pokemonLon, pokemonEncounterIdResult, targetLat, targetLon, (onlyEmptyGmos ? "Yes" : "No"), (onlyInvalidGmos ? "Yes" : "No"), (containsGmo ? "Yes" : "No"));
        //syslog(@"[DEBUG] SpinFortLat: %@ SpinFortLon: %@", spinFortLat, spinFortLon);

        /*
        NSNumber *itemDistance = @10000.0;
        if (![spinFortId isMemberOfClass:[NSNull class]] && ![spinFortLat isMemberOfClass:[NSNull class]]) {
            if ([spinFortLat doubleValue] != 0.0) {
                CLLocation *fortLocation = [Utils createCoordinate:[spinFortLat doubleValue] lon:[spinFortLon doubleValue]];
                NSNumber *itemDistance = [NSNumber numberWithDouble:[fortLocation distanceFromLocation:currentLoc]];
                syslog(@"[DEBUG] ItemDistance: %@", itemDistance);
            }
        }
        */
        // End MIZU tut stuff
        
        NSString *msg;
        NSNumber *pokemonFoundCount = @([wild intValue] + [nearby intValue]);
        if (onlyInvalidGmos) {
            [[DeviceState sharedInstance] setWaitForData:false];
            msg = @"Got GMO but it was malformed. Skipping.";
        } else if (containsGmo) {
            if (inArea && [diffLat doubleValue] < 0.0001 && [diffLon doubleValue] < 0.0001) {
                [[DeviceState sharedInstance] setEmptyGmoCount:@0];
                NSString *pokemonEncounterId = [[DeviceState sharedInstance] pokemonEncounterId];
                if (pokemonEncounterId != nil) {
                    if ([pokemonFoundCount intValue] > 0) {
                        if (pokemonLat != 0 && pokemonLon != 0 && pokemonEncounterId == pokemonEncounterIdResult) {
                            [[DeviceState sharedInstance] setWaitRequiresPokemon:false];
                            //CLLocation *oldLocation = [[DeviceState sharedInstance] currentLocation];
                            [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[pokemonLat doubleValue]
                                                                                                 lon:[pokemonLon doubleValue]]];
                            //CLLocation *newLocation = [[DeviceState sharedInstance] currentLocation];
                            //_encounterDistance = [NSNumber numberWithDouble:[newLocation distanceFromLocation:oldLocation]];
                            [[DeviceState sharedInstance] setPokemonEncounterId:nil];
                            [[DeviceState sharedInstance] setWaitForData:false];
                            msg = @"Got Data and found Pokemon";
                        } else {
                            msg = @"Got Data but did not find Pokemon";
                        }
                    } else {
                        msg = @"Got Data without Pokemon";
                    }
                } else if ([[DeviceState sharedInstance] waitRequiresPokemon]) {
                    if ([pokemonFoundCount intValue] > 0) {
                        msg = @"Got Data with Pokemon";
                        [[DeviceState sharedInstance] setWaitForData:false];
                    } else {
                        msg = @"Got Data without Pokemon";
                    }
                } else {
                    msg = @"Got Data";
                    [[DeviceState sharedInstance] setWaitForData:false];
                }
            } else if (onlyEmptyGmos && ![[DeviceState sharedInstance] isStartup]) {
                NSNumber *emptyGmoCount = [[DeviceState sharedInstance] emptyGmoCount];
                [[DeviceState sharedInstance] setEmptyGmoCount:[Utils incrementInt:emptyGmoCount]];
                msg = @"Got Empty Data";
            } else {
                [[DeviceState sharedInstance] setEmptyGmoCount:@0];
                msg = @"Got Data outside Target-Area";
            }
        } else {
            msg = @"Got Data without GMO";
        }

        if (![[DeviceState sharedInstance] gotQuest] && [quests intValue] > 0) {
            [[DeviceState sharedInstance] setGotQuest:true];
            [[DeviceState sharedInstance] setGotQuestEarly:true];
            syslog(@"[DEBUG] Got quest.");
        }
        
        if (![[DeviceState sharedInstance] gotItems] && [items intValue] > 0) {//} && [itemDistance doubleValue] < 30.0) {
            [[DeviceState sharedInstance] setGotItems:true];
            syslog(@"[DEBUG] Got items.");
        }
        
        if (![[DeviceState sharedInstance] gotIV] && [encounters intValue] > 0) {
            [[DeviceState sharedInstance] setGotIV:true];
            syslog(@"[DEBUG] Got IV.");
        }
        
        syslog(@"[DEBUG] [GMO] %@", msg);
    }];
    NSString *response = [Utils toJsonString:data withPrettyPrint:false];
    return response;
}

/**
 Handle `/touch` web requests.
 Data: { "x" = 160, "y" = 275 }
 */
-(NSString *)handleTouchRequest:(NSDictionary *)params
{
    [JarvisTestCase touch:[params[@"x"] intValue]
                    withY:[params[@"y"] intValue]
    ];
    return JSON_OK;
}

/**
 Handle `/type` web requests.
 Data: { "text" = "Type this" }
 */
-(NSString *)handleTypeRequest:(NSDictionary *)params
{
    [JarvisTestCase type:params[@"text"]];
    return JSON_OK;
}

/**
 Handle `/config` web requests.
 */
-(NSString *)handleConfigRequest
{
    NSDictionary *config = [[Settings sharedInstance] config];
    NSString *json = [Utils toJsonString:config withPrettyPrint:true];
    return json ?: JSON_ERROR;
}

/**
 Handle `/pixel` web requests.
 Data: { "x" = 320, "y" = 520 }
 */
-(NSString *)handlePixelRequest:(NSDictionary *)params
{
    syslog(@"[DEBUG] handlePixelRequest: %@", params);
    /*
    @try {
        __block NSNumber *x = params[@"x"];
        __block NSNumber *y = params[@"y"];
        __block UIColor *color;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *image = [Utils takeScreenshot];
            color = [image getPixelColor:[x intValue] withY:[y intValue]];
            dispatch_semaphore_signal(sem);
        });
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        if (color == nil) {
            syslog(@"[ERROR] Failed to get rgbAtLocation x=%@ y=%@", x, y);
        } else {
            syslog(@"[DEBUG] rgbAtLocation: x=%@ y=%@ color=%@", x, y, color);
        }
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"x"] = x;
        dict[@"y"] = y;
        dict[@"color"] = color;
        NSString *json = [Utils toJsonString:dict withPrettyPrint:true];
        return json ?: JSON_ERROR;
    }
    @catch (NSException *exception) {
        syslog(@"[ERROR] handlePixelRequest: %@", exception);
    }
    return JSON_ERROR;
    */
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
    return JSON_OK;

}

-(NSString *)handleClearRequest
{
    syslog(@"[INFO] Clearing user defaults");
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:TOKEN_USER_DEFAULT_KEY];
    [[Device sharedInstance] setUsername:nil];
    [[Device sharedInstance] setPassword:nil];
    [[Device sharedInstance] setLuckyEggsCount:@0];
    [[Device sharedInstance] setLastEggDeployTime:nil];
    [DeviceState restart];
    return JSON_OK;
}

/**
 * Send restart application request.
 */
-(NSString *)handleRestartRequest
{
    syslog(@"[INFO] Restarting per user request");
    [DeviceState restart];
    return JSON_OK;
}

-(NSString *)handleAccountRequest
{
    syslog(@"[INFO] Received account request from client for auto login.");
    //NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    //data[@"username"] = [[Device sharedInstance] username];
    //data[@"password"] = [[Device sharedInstance] password];
    //NSString *response = [Utils toJsonString:data withPrettyPrint:true];
    if ([[Settings sharedInstance] autoLogin]) {
        NSString *response = [NSString stringWithFormat:@"{\"username\":\"%@\",\"password\":\"%@\"}",
                              [[Device sharedInstance] username],
                              [[Device sharedInstance] password]];
        syslog(@"[INFO] Auto login account response: %@", response);
        return response;
    }
    return JSON_OK;
}

-(NSString *)handleScreenRequest
{
    syslog(@"[INFO] Received screenshot request from user");
    dispatch_async(dispatch_get_main_queue(), ^{
       [Utils sendScreenshot];
    });
    return JSON_OK;
}

-(NSString *)handleSystemInfoRequest
{
    syslog(@"[INFO] Received system info request from user");
    //NSDictionary *dict = [[SystemInfo sharedInstance] dictionary];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    @try {
        dict[@"uuid"] = [[Device sharedInstance] uuid];
        dict[@"model"] = [[Device sharedInstance] model];
        dict[@"ios_version"] = [[Device sharedInstance] osVersion];
        dict[@"cpu_usage"] = [[SystemInfo sharedInstance] cpuUsage];
        //dict[@"cpu_count"] = (unsigned long)[[SystemInfo sharedInstance] processorCount];
        dict[@"thermal_state"] = [SystemInfo formatThermalState:[[SystemInfo sharedInstance] thermalState]];
        dict[@"system_uptime"] = [SystemInfo formatTimeInterval:[[SystemInfo sharedInstance] systemUptime]];
        dict[@"ram_total"] = [[SystemInfo sharedInstance] totalMemory];
        dict[@"ram_free"] = [[SystemInfo sharedInstance] freeMemory];
        dict[@"ram_used"] = [[SystemInfo sharedInstance] usedMemory];
        dict[@"hdd_total"] = [[SystemInfo sharedInstance] totalSpace];
        dict[@"hdd_free"] = [[SystemInfo sharedInstance] freeSpace];
        dict[@"hdd_used"] = [[SystemInfo sharedInstance] usedSpace];
    }
    @catch (NSException *exception) {
        syslog(@"[ERROR] handleSystemInfoRequest: %@", exception);
    }
    NSString *json = [Utils toJsonString:dict withPrettyPrint:true];
    return json ?: JSON_ERROR;
}

/**
 Handle `/test` web requests. Development purposes.
 */
-(NSString *)handleTestRequest:(NSDictionary *)params
{
    syslog(@"[DEBUG] handleTestRequest: %@", params);
    
    //[self showMessage:@"This is a test message" withTitle:@"Test title"];
    [JarvisTestCase test];
    /*
    //dispatch_async(dispatch_get_main_queue(), ^{
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
    //DeviceCoordinate *ageVerify = [[DeviceConfig sharedInstance] ageVerification];
    
    return JSON_OK;
}

@end
