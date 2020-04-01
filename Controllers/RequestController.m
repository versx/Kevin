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
    syslog(@"[INFO] init");
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
    //self.lock.lock();
    CLLocation *currentLoc = [[DeviceState sharedInstance] currentLocation];
    if (currentLoc != nil) {
        if ([[DeviceState sharedInstance] waitRequiresPokemon]) {
            //self.lock.unlock();
            double jitterValue = [[[Settings sharedInstance] jitterValue] doubleValue];
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
    //syslog(@"[DEBUG] [LOC] %@", response);
    return response;
}

/**
 Handle `/data` web requests.
 */
-(NSString *)handleDataRequest:(NSDictionary *)params
{
    CLLocation *currentLocation = [[DeviceState sharedInstance] currentLocation];
    //if (currentLocation == nil) {
    //    return @"{\"status\": \"error\", \"message\": \"currentLocation is null\"}";
    //}
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
    data[@"uuid_control"] = [[Device sharedInstance] uuid];
    data[@"ptcToken"] = [[Device sharedInstance] ptcToken] ?: @"";
    
    //dispatch_semaphore_t sem = dispatch_semaphore_create(0);
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

        [[Device sharedInstance] setLevel:level];
        
        //self.lock.lock();
        NSNumber *diffLat = @(currentLoc.coordinate.latitude - [targetLat doubleValue]);
        NSNumber *diffLon = @(currentLoc.coordinate.longitude - [targetLon doubleValue]);
        
        // MIZU tut stuff
        //NSString *spinFortId = data[@"spin_fort_id"] ?: @"";
        //NSNumber *spinFortLat = data[@"spin_fort_lat"] ?: @0.0;
        //NSNumber *spinFortLon = data[@"spin_fort_lon"] ?: @0.0;
        if ([level intValue] > 0) {
            // TODO: Use luckyegg_count from lorgnette
            if ([[Device sharedInstance] level] != level) {
                NSNumber *luckyEggsCount = [[DeviceState sharedInstance] luckyEggsCount];
                switch ([level intValue]) {
                    case 9:
                        [[DeviceState sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount]];
                        break;
                    case 10:
                        [[DeviceState sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount withAmount:@2]];
                        break;
                    case 15:
                        [[DeviceState sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount withAmount:@3]];
                        break;
                    case 20:
                        [[DeviceState sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount withAmount:@4]];
                        break;
                    case 25:
                        [[DeviceState sharedInstance] setLuckyEggsCount:[Utils incrementInt:luckyEggsCount withAmount:@5]];
                        break;
                }
            }
            [[Device sharedInstance] setLevel:level];
        }

        //syslog(@"[DEBUG] [RES1] inArea: %s level: %@ nearby: %@ wild: %@ quests: %@ encounters: %@ plat: %@ plon: %@ encounterResponseId: %@ tarlat: %@ tarlon: %@ emptyGMO: %s invalidGMO: %s containsGMO: %s", (inArea ? "Yes" : "No"), level, nearby, wild, quests, encounters, pokemonLat, pokemonLon, pokemonEncounterIdResult, targetLat, targetLon, (onlyEmptyGmos ? "Yes" : "No"), (onlyInvalidGmos ? "Yes" : "No"), (containsGmo ? "Yes" : "No"));
        //syslog(@"[DEBUG] SpinFortLat: %@ SpinFortLon: %@", spinFortLat, spinFortLon);

        //NSNumber *itemDistance = @10000.0;
        /*
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
                            [[DeviceState sharedInstance] setCurrentLocation:[Utils createCoordinate:[pokemonLat doubleValue] lon:[pokemonLon doubleValue]]];
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

        if (![[DeviceState sharedInstance] gotQuest] && quests > 0) {
            [[DeviceState sharedInstance] setGotQuest:true];
            [[DeviceState sharedInstance] setGotQuestEarly:true];
        }
        
        if (![[DeviceState sharedInstance] gotIV] && encounters > 0) {
            [[DeviceState sharedInstance] setGotIV:true];
        }
        
        syslog(@"[DEBUG] [GMO] %@", msg);
        //dispatch_semaphore_signal(sem);
    }];
    //dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
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
 Handle `/swipe` web requests.
 */
-(NSString *)handleSwipeRequest
{
    [JarvisTestCase swipe];
    return JSON_OK;
}

/**
 Handle `/config` web requests.
 */
-(NSString *)handleConfigRequest
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

/**
 Handle `/pixel` web requests.
 Data: { "x" = 320, "y" = 520 }
 */
-(NSString *)handlePixelRequest:(NSDictionary *)params
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
    return JSON_OK;
}

-(NSString *)handleClearRequest
{
    syslog(@"[INFO] Clearing user defaults");
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:TOKEN_USER_DEFAULT_KEY];
    [[Device sharedInstance] setUsername:nil];
    [[Device sharedInstance] setPassword:nil];
    [DeviceState restart];
    return JSON_OK;
}

-(NSString *)handleRestartRequest
{
    syslog(@"[INFO] Restarting per user request");
    [DeviceState restart];
    return JSON_OK;
}

/**
 Handle `/test` web requests.
 */
-(NSString *)handleTestRequest:(NSDictionary *)params
{
    syslog(@"[DEBUG] handleTestRequest: %@", params);
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
    
    return JSON_OK;
}

@end