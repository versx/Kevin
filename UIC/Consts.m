//
//  Consts.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "Consts.h"

@implementation Consts

// UserDefaults keys
NSString *BIRTHDAY_USER_DEFAULT_KEY = @"4b9b44d8-66f5-46dc-86bb-0215bfa90f5e";
NSString *TOKEN_USER_DEFAULT_KEY = @"5750bac0-483c-4131-80fd-6b047b2ca7b4";
NSString *LOGIN_USER_DEFAULT_KEY = @"60b01025-c1ea-422c-9b0e-d70bf489de7f";

// Web Request Types
NSString *TYPE_INIT = @"init";
NSString *TYPE_HEARTBEAT = @"heartbeat";
NSString *TYPE_GET_ACCOUNT = @"get_account";
NSString *TYPE_GET_JOB = @"get_job";
NSString *TYPE_JOB_FAILED = @"job_failed";
NSString *TYPE_TUTORIAL_DONE = @"tutorial_done";
NSString *TYPE_LOGGED_OUT = @"logged_out";
NSString *TYPE_ACCOUNT_BANNED = @"account_banned";
NSString *TYPE_ACCOUNT_INVALID_CREDENTIALS = @"account_invalid_credentials";
NSString *TYPE_PTC_TOKEN = @"ptcToken";

// Status Responses
NSString *JSON_OK = @"{\"status\": \"ok\"}";
NSString *JSON_ERROR = @"{\"status\": \"error\", \"message\": \"currentLocation is null\"}";

int DEFAULT_BDAY = 19710101;

// UIC defaults
int DEFAULT_PORT = 8080;
int DEFAULT_TARGET_MAX_DISTANCE = 250;
int DEFAULT_HEARTBEAT_MAX_TIME = 120;
int DEFAULT_POKEMON_MAX_TIME = 25;
int DEFAULT_RAID_MAX_TIME = 25;
double DEFAULT_JITTER_VALUE = 0.00005;//5.0e-05;
int DEFAULT_MAX_EMPTY_GMO = 50;
int DEFAULT_MAX_FAILED_COUNT = 5;
int DEFAULT_MAX_NO_QUEST_COUNT = 5;
int DEFAULT_MAX_WARNING_TIME_RAID = 432000;
int DEFAULT_MIN_DELAY_LOGOUT = 180;

@end
