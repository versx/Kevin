//
//  Settings.m
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import "Settings.h"

@implementation Settings

static NSDictionary *_config;
static NSString *_homebaseUrl;
static NSString *_backendControllerUrl;
static NSString *_backendRawUrl;
static NSString *_token;
static int  _heartbeatMaxTime;
static int _minDelayLogout;
static bool _enableAccountManager;
static bool _deployEggs;
static bool _nearbyTracker;
static bool _autoLogin;
static bool _allowWarnedAccounts;

static bool _gotConfig;

static NSString *plistFileName = @"config.plist";

-(NSDictionary *)config {
    return _config;
}

-(NSString *)homebaseUrl {
    return _homebaseUrl;
}
-(NSString *)backendControllerUrl {
    return _backendControllerUrl;
}
-(NSString *)backendRawUrl {
    return _backendRawUrl;
}
-(NSString *)token {
    return _token;
}
-(int)port {
    return DEFAULT_PORT;
}
-(int)heartbeatMaxTime {
    return _heartbeatMaxTime;
}
-(int)pokemonMaxTime {
    return DEFAULT_POKEMON_MAX_TIME;
}
-(int)raidMaxTime {
    return DEFAULT_RAID_MAX_TIME;
}
-(double)jitterValue {
    return DEFAULT_JITTER_VALUE;
}
-(int)maxEmptyGMO {
    return DEFAULT_MAX_EMPTY_GMO;
}
-(int)maxFailedCount {
    return DEFAULT_MAX_FAILED_COUNT;
}
-(int)maxNoQuestCount {
    return DEFAULT_MAX_NO_QUEST_COUNT;
}
-(int)maxWarningTimeRaid {
    return DEFAULT_MAX_WARNING_TIME_RAID;
}
-(int)minDelayLogout {
    return _minDelayLogout;
}
-(bool)enableAccountManager {
    return _enableAccountManager;
}
-(bool)deployEggs {
    return _deployEggs;
}
-(bool)nearbyTracker {
    return _nearbyTracker;
}
-(bool)autoLogin {
    return _autoLogin;
}
-(bool)allowWarnedAccounts {
    return _allowWarnedAccounts;
}

-(bool)gotConfig {
    return _gotConfig;
}


+(Settings *)sharedInstance
{
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];

        _homebaseUrl = [sharedInstance getRemoteConfigUrl];
        if (_homebaseUrl == nil) {
            NSLog(@"[Jarvis] [Settings] [FATAL] Failed to fetch remote config url, waiting 30 seconds then restarting...");
            sleep(30);
            [DeviceState restart];
            return;
        }

        NSDictionary *result;
        NSString *url = [NSString stringWithFormat:@"%@/api/config/%@", _homebaseUrl, [[Device sharedInstance] uuid]];
        bool gotConfig = false;
        //while (!gotConfig) {
            result = [sharedInstance fetchJsonConfig:url];
            if (result == nil || [result[@"status"] isEqualToString:@"error"]) {
                NSLog(@"[Jarvis] [Settings] [ERROR] Failed to grab config error: %@ Trying again in 30 seconds...", result[@"error"] ?: @"Are you sure DeviceConfigManager is up?");
                //sleep(30);
                //continue;
            }
            sleep(3);
            _config = result;
            gotConfig = true;
        //}
        NSLog(@"[Jarvis] [Settings] [INFO] Got config: %@", result);
        if (result == nil) {
            NSLog(@"[Jarvis] [Settings] [ERROR] Some how returned a nil config.");
            return;
        }

        NSString *backendUrl = result[@"backend_url"];
        NSArray *dataEndpoints = [result objectForKey:@"data_endpoints"];
        _backendControllerUrl = [NSString stringWithFormat:@"%@/controler", backendUrl];
        _backendRawUrl = [NSString stringWithFormat:@"%@/raw", dataEndpoints[0]];
        _token = result[@"backend_secret_token"] ?: @"";
        _heartbeatMaxTime = [result[@"heartbeat_max_time"] intValue] ?: DEFAULT_HEARTBEAT_MAX_TIME;
        _minDelayLogout = [result[@"min_delay_logout"] intValue] ?: DEFAULT_MIN_DELAY_LOGOUT;
        _enableAccountManager = [[result objectForKey:@"account_manager"] boolValue];
        _deployEggs = [[result objectForKey:@"deploy_eggs"] boolValue];
        _nearbyTracker = [[result objectForKey:@"nearby_tracker"] boolValue];
        _autoLogin = [[result objectForKey:@"auto_login"] boolValue];
        _allowWarnedAccounts = false;//[[result objectForKey:@"allow_warned_accounts"] boolValue];
        _gotConfig = true;
    });
    return sharedInstance;
}

-(NSString *)getRemoteConfigUrl
{
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *plistPath = [bundlePath stringByAppendingPathComponent:plistFileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:plistPath]) {
        NSLog(@"[Jarvis] [Settings] [ERROR] %@ DOES NOT EXIST!", plistPath);
        return nil;
    }
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    NSLog(@"[Jarvis] [Settings] [DEBUG] %@ - %@", plistPath, dict);
    return dict[@"url"];
}

-(NSDictionary *)fetchJsonConfig:(NSString *)urlString
{
    @try {
        NSURL *urlRequest = [NSURL URLWithString:urlString];
        NSError *error = nil;
        NSString *json = [NSString stringWithContentsOfURL:urlRequest
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                               options:NSJSONReadingMutableContainers
                                                                 error:&error];
        if (error) {
            NSLog(@"[Jarvis] [ERROR] Failed to fetch json config %@ Error:%@", urlString, error);
            return nil;
        }
        return result;
    }
    @catch (NSException *exception) {
        NSLog(@"[Jarvis] [ERROR] Failed to fetch json config %@ Exception: %@", urlString, exception);
    }
    return nil;
}

-(NSDictionary *)getConfigOrWait
{
    NSDictionary *dict;
    NSString *url = [NSString stringWithFormat:@"%@/api/config/%@", _homebaseUrl, [[Device sharedInstance] uuid]];
    bool gotConfig = false;
    while (!gotConfig) {
        dict = [self fetchJsonConfig:url];
        if (dict == nil || [dict[@"status"] isEqualToString:@"error"]) {
            NSLog(@"[Jarvis] [Settings] [ERROR] Failed to grab config error: %@ Trying again in 30 seconds...", dict[@"error"] ?: @"Are you sure DeviceConfigManager is up?");
            sleep(30);
            continue;
        }
        sleep(3);
        gotConfig = true;
    }
    return dict;
}

-(void)getConfigOrWait:(void (^)(NSDictionary* result))completion
{
    NSString *url = [NSString stringWithFormat:@"%@/api/config/%@", _homebaseUrl, [[Device sharedInstance] uuid]];
    dispatch_async(dispatch_queue_create("config_queue", NULL), ^{
        NSDictionary *dict;
        bool gotConfig = false;
        while (!gotConfig) {
            dict = [self fetchJsonConfig:url];
            if (dict == nil || [dict[@"status"] isEqualToString:@"error"]) {
                NSLog(@"[Jarvis] [Settings] [ERROR] Failed to grab config error: %@ Trying again in 30 seconds...", dict[@"error"] ?: @"Are you sure DeviceConfigManager is up?");
                sleep(30);
                continue;
            }
            sleep(3);
            gotConfig = true;
        }
        //NSLog(@"[Jarvis] broke while loop: %@", dict);
        completion(dict);
    });
}

@end
