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
static NSString *_pixelConfigUrl;
static int _port;
static int _targetMaxDistance;
static int  _heartbeatMaxTime;
static int _pokemonMaxTime;
static int _raidMaxTime;
static double _jitterValue;
static int _maxEmptyGMO;
static int _maxFailedCount;
static int _maxNoQuestCount;
static int _maxWarningTimeRaid;
static int _minDelayLogout;
static bool _enableAccountManager;
static bool _deployEggs;
static bool _nearbyTracker;
static bool _autoLogin;
static bool _ultraIV;
static bool _ultraQuests;
static bool _allowWarnedAccounts;

static NSString *_loggingUrl;
static NSNumber *_loggingPort;
static bool _loggingTls;
static bool _loggingTcp; // Use TCP, otherwise UDP protocol

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
-(NSString *)pixelConfigUrl {
    return _pixelConfigUrl;
}
-(NSString *)token {
    return _token;
}
-(int)port {
    return _port;
}
-(int)targetMaxDistance {
    return _targetMaxDistance;
}
-(int)heartbeatMaxTime {
    return _heartbeatMaxTime;
}
-(int)pokemonMaxTime {
    return _pokemonMaxTime;
}
-(int)raidMaxTime {
    return _raidMaxTime;
}
-(double)jitterValue {
    return _jitterValue;
}
-(int)maxEmptyGMO {
    return _maxEmptyGMO;
}
-(int)maxFailedCount {
    return _maxFailedCount;
}
-(int)maxNoQuestCount {
    return _maxNoQuestCount;
}
-(int)maxWarningTimeRaid {
    return _maxWarningTimeRaid;
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
-(bool)ultraIV {
    return _ultraIV;
}
-(bool)ultraQuests {
    return _ultraQuests;
}
-(bool)allowWarnedAccounts {
    return _allowWarnedAccounts;
}

-(NSString *)loggingUrl {
    return _loggingUrl;
}
-(int)loggingPort {
    return _loggingPort;
}
-(bool)loggingTls {
    return _loggingTls;
}
-(bool)loggingTcp {
    return _loggingTcp;
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
        while (!gotConfig) {
            result = [sharedInstance fetchJsonConfig:url];
            if (result == nil || [result[@"status"] isEqualToString:@"error"]) {
                NSLog(@"[Jarvis] [Settings] [ERROR] Failed to grab config error: %@ Trying again in 30 seconds...", result[@"error"] ?: @"Are you sure DeviceConfigManager is up?");
                sleep(30);
                continue;
            }
            sleep(3);
            _config = result;
            gotConfig = true;
        }
        NSLog(@"[Jarvis] [Settings] [INFO] Got config: %@", result);
        if (result == nil) {
            NSLog(@"[Jarvis] [Settings] [ERROR] Some how returned a nil config.");
            return;
        }

        NSString *backendUrl = result[@"backendURL"];
        _backendControllerUrl = [NSString stringWithFormat:@"%@/controler", backendUrl];
        _backendRawUrl = [NSString stringWithFormat:@"%@/raw", backendUrl];
        _pixelConfigUrl = result[@"pixelConfigURL"];
        _token = result[@"token"] ?: @"";
        _port = [result[@"port"] intValue];// ?: DEFAULT_PORT;
        // TODO: Startup lat/lon
        _targetMaxDistance = /*[result[@"targetMaxDistance"] intValue] ?:*/ DEFAULT_TARGET_MAX_DISTANCE;
        _heartbeatMaxTime = [result[@"heartbeatMaxTime"] intValue] ?: DEFAULT_HEARTBEAT_MAX_TIME;
        _pokemonMaxTime = [result[@"pokemonMaxTime"] intValue] ?: DEFAULT_POKEMON_MAX_TIME;
        _raidMaxTime = [result[@"raidMaxTime"] intValue] ?: DEFAULT_RAID_MAX_TIME;
        _jitterValue = [result[@"jitterValue"] doubleValue] ?: 5.0e-05; // 5.0e-05 0.000005 // ?: DEFAULT_JITTER_VALUE;
        _maxEmptyGMO = [result[@"maxEmptyGMO"] intValue] ?: DEFAULT_MAX_EMPTY_GMO;
        _maxFailedCount = [result[@"maxFailedCount"] intValue] ?: DEFAULT_MAX_FAILED_COUNT;
        _maxNoQuestCount = [result[@"maxNoQuestCount"] intValue] ?: DEFAULT_MAX_NO_QUEST_COUNT;
        _maxWarningTimeRaid = [result[@"maxWarningTimeRaid"] intValue] ?: DEFAULT_MAX_WARNING_TIME_RAID;
        _minDelayLogout = [result[@"minDelayLogout"] intValue] ?: DEFAULT_MIN_DELAY_LOGOUT;
        _enableAccountManager = [[result objectForKey:@"accountManager"] boolValue];
        _deployEggs = [[result objectForKey:@"deployEggs"] boolValue];
        _nearbyTracker = [[result objectForKey:@"nearbyTracker"] boolValue];
        _autoLogin = [[result objectForKey:@"autoLogin"] boolValue];
        _ultraIV = [[result objectForKey:@"ultraIV"] boolValue];
        _ultraQuests = [[result objectForKey:@"ultraQuests"] boolValue];
        _allowWarnedAccounts = [[result objectForKey:@"allowWarnedAccounts"] boolValue];
        
        _loggingUrl = result[@"loggingURL"] ?: @"";
        _loggingPort = [result[@"loggingPort"] intValue];// ?: @9999;
        _loggingTls = [[result objectForKey:@"loggingTLS"] boolValue];// ?: false;
        _loggingTcp = [[result objectForKey:@"loggingTCP"] boolValue];// ?: true;
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
