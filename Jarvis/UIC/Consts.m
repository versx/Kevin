//
//  Consts.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "Consts.h"

@implementation Consts

NSString *TOKEN_USER_DEFAULT_KEY = @"5750bac0-483c-4131-80fd-6b047b2ca7b4";
NSString *LOGIN_USER_DEFAULT_KEY = @"60b01025-clea-422c-9b0e-d70bf489de7f";

NSString *HTTP_200_RESPONSE = @"HTTP/1.1 200 OK\nContent-Type: application/json; charset=utf-8\n\n";
NSString *HTTP_400_RESPONSE = @"HTTP/1.1 400 Bad Request\nContent-Type: application/json; charset=utf-8\n\n";
NSString *HTTP_404_RESPONSE = @"HTTP/1.1 404 Not Found\nContent-Type: application/json; charset=utf-8\n\n";

NSNumber *DEFAULT_MIN_LEVEL = 1;
NSNumber *DEFAULT_MAX_LEVEL = 29;
NSNumber *DEFAULT_PORT = 8080;
NSNumber *DEFAULT_TARGET_MAX_DISTANCE = 250;
NSNumber *DEFAULT_POKEMON_MAX_TIME = 25;
NSNumber *DEFAULT_RAID_MAX_TIME = 25;
NSNumber *DEFAULT_ENCOUNTER_DELAY = 0;
NSNumber *DEFAULT_MAX_EMPTY_GMO = 50;
NSNumber *DEFAULT_MAX_FAILED_COUNT = 5;
NSNumber *DEFAULT_MAX_NO_QUEST_COUNT = 5;
NSNumber *DEFAULT_MAX_WARNING_TIME_RAID = 432000;
NSNumber *DEFAULT_MIN_DELAY_LOGOUT = 180;
BOOL DEFAULT_ENABLE_ACCOUNT_MANAGER = false;
BOOL DEFAULT_ULTRA_QUESTS = false;
BOOL DEFAULT_DEPLOY_EGGS = false;

@end
