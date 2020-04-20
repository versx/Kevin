//
//  Consts.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

@interface Consts : NSObject

extern NSString *BIRTHDAY_USER_DEFAULT_KEY;
extern NSString *TOKEN_USER_DEFAULT_KEY;
extern NSString *LOGIN_USER_DEFAULT_KEY;

extern NSString *TYPE_INIT;
extern NSString *TYPE_HEARTBEAT;
extern NSString *TYPE_GET_ACCOUNT;
extern NSString *TYPE_GET_JOB;
extern NSString *TYPE_JOB_FAILED;
extern NSString *TYPE_TUTORIAL_DONE;
extern NSString *TYPE_LOGGED_OUT;
extern NSString *TYPE_ACCOUNT_BANNED;
extern NSString *TYPE_ACCOUNT_INVALID_CREDENTIALS;
extern NSString *TYPE_PTC_TOKEN;

extern NSString *JSON_OK;
extern NSString *JSON_ERROR;

extern int DEFAULT_BDAY;

//extern NSNumber *DEFAULT_MIN_LEVEL;
//extern NSNumber *DEFAULT_MAX_LEVEL;
extern int DEFAULT_PORT;
extern int DEFAULT_TARGET_MAX_DISTANCE;
extern int DEFAULT_HEARTBEAT_MAX_TIME;
extern int DEFAULT_POKEMON_MAX_TIME;
extern int DEFAULT_RAID_MAX_TIME;
extern double DEFAULT_JITTER_VALUE;
extern int DEFAULT_MAX_EMPTY_GMO;
extern int DEFAULT_MAX_FAILED_COUNT;
extern int DEFAULT_MAX_NO_QUEST_COUNT;
extern int DEFAULT_MAX_WARNING_TIME_RAID;
extern int DEFAULT_MIN_DELAY_LOGOUT;

@end
