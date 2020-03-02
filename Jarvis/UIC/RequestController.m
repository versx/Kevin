//
//  RequestController.m
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import "RequestController.h"

@implementation RequestController

static NSDictionary *_config;

+(RequestController *)sharedInstance
{
    static RequestController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RequestController alloc] init];
        //_config = [sharedInstance loadSettings];
        //_enableAccountManager = [_config objectForKey:@""] ?: false;
    });
    return sharedInstance;
}

/*
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
*/

@end
