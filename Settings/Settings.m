//
//  Settings.m
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import "Settings.h"

@implementation Settings

static NSDictionary *_config;
static bool _enableAccountManager;
static NSString *_backendControllerUrl;
static NSString *_backendRawUrl;
static NSString *_token;
static NSString *_pixelConfigUrl;
static NSNumber *_port;
static NSNumber *_delayMultiplier;
static NSNumber *_targetMaxDistance;
static NSNumber * _heartbeatMaxTime;
static NSNumber *_pokemonMaxTime;
static NSNumber *_raidMaxTime;
static NSNumber *_jitterValue;
static NSNumber *_maxEmptyGMO;
static NSNumber *_maxFailedCount;
static NSNumber *_maxNoQuestCount;
static NSNumber *_maxWarningTimeRaid;
static NSNumber *_minDelayLogout;
static bool _ultraIV;
static bool _ultraQuests;
static bool _deployEggs;
static bool _nearbyTracker;
static bool _autoLogin;

static NSString *_loggingUrl;
static NSNumber *_loggingPort;
static bool _loggingTls;
static bool _loggingTcp; // Use TCP, otherwise UDP protocol

static NSString *plistFileName = @"config.plist";

-(NSDictionary *)config {
    return _config;
}

-(bool)enableAccountManager {
    return _enableAccountManager;
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
-(NSNumber *)port {
    return _port;
}
-(NSNumber *)targetMaxDistance {
    return _targetMaxDistance;
}
-(NSNumber *)heartbeatMaxTime {
    return _heartbeatMaxTime;
}
-(NSNumber *)pokemonMaxTime {
    return _pokemonMaxTime;
}
-(NSNumber *)raidMaxTime {
    return _raidMaxTime;
}
-(NSNumber *)jitterValue {
    return _jitterValue;
}
-(NSNumber*)maxEmptyGMO {
    return _maxEmptyGMO;
}
-(NSNumber*)maxFailedCount {
    return _maxFailedCount;
}
-(NSNumber *)maxNoQuestCount {
    return _maxNoQuestCount;
}
-(NSNumber *)maxWarningTimeRaid {
    return _maxWarningTimeRaid;
}
-(NSNumber *)minDelayLogout {
    return _minDelayLogout;
}
-(bool)ultraIV {
    return _ultraIV;
}
-(bool)ultraQuests {
    return _ultraQuests;
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

-(NSString *)loggingUrl {
    return _loggingUrl;
}
-(NSNumber *)loggingPort {
    return _loggingPort;
}
-(bool)loggingTls {
    return _loggingTls;
}
-(bool)loggingTcp {
    return _loggingTcp;
}

+(Settings *)sharedInstance
{
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
        NSString *remoteConfigUrl = [sharedInstance getRemoteConfigUrl];
        if (remoteConfigUrl == nil) {
            NSLog(@"[Jarvis] [FATAL] Failed to fetch remote config, waiting 10 seconds then restarting...");
            sleep(10);
            [DeviceState restart];
            return;
        }
        _config = [sharedInstance fetchRemoteConfig:remoteConfigUrl];//[sharedInstance loadSettings];
        _enableAccountManager = [[_config objectForKey:@"enableAccountManager"] boolValue];
        _backendControllerUrl = _config[@"backendControllerURL"];
        _backendRawUrl = _config[@"backendRawURL"];
        _pixelConfigUrl = _config[@"pixelConfigURL"];
        _token = _config[@"token"] ?: @"";
        _port = _config[@"port"] ?: DEFAULT_PORT;
        _delayMultiplier = _config[@"delayMultiplier"] ?: DEFAULT_DELAY_MULTIPLIER;
        _targetMaxDistance = _config[@"targetMaxDistance"] ?: DEFAULT_TARGET_MAX_DISTANCE;
        _heartbeatMaxTime = _config[@"heartbeatMaxTime"] ?: DEFAULT_HEARTBEAT_MAX_TIME;
        _pokemonMaxTime = _config[@"pokemonMaxTime"] ?: DEFAULT_POKEMON_MAX_TIME;
        _raidMaxTime = _config[@"raidMaxTime"] ?: DEFAULT_RAID_MAX_TIME;
        _jitterValue = _config[@"jitterValue"] ?: @(5.0e-05); // 5.0e-05 0.000005 // ?: DEFAULT_JITTER_VALUE;
        _maxEmptyGMO = _config[@"maxEmptyGMO"] ?: DEFAULT_MAX_EMPTY_GMO;
        _maxFailedCount = _config[@"maxFailedCount"] ?: DEFAULT_MAX_FAILED_COUNT;
        _maxNoQuestCount = _config[@"maxNoQuestCount"] ?: DEFAULT_MAX_NO_QUEST_COUNT;
        _maxWarningTimeRaid = _config[@"maxWarningTimeRaid"] ?: DEFAULT_MAX_WARNING_TIME_RAID;
        _minDelayLogout = _config[@"minDelayLogout"] ?: DEFAULT_MIN_DELAY_LOGOUT;
        _ultraIV = [[_config objectForKey:@"ultraIV"] boolValue];
        _ultraQuests = [[_config objectForKey:@"ultraQuests"] boolValue];
        _deployEggs = [[_config objectForKey:@"deployEggs"] boolValue];
        _nearbyTracker = [[_config objectForKey:@"nearbyTracker"] boolValue];
        _autoLogin = [[_config objectForKey:@"autoLogin"] boolValue];
        
        _loggingUrl = _config[@"loggingURL"] ?: @"";
        _loggingPort = _config[@"loggingPort"] ?: @9999;
        _loggingTls = [[_config objectForKey:@"loggingTLS"] boolValue];// ?: false;
        _loggingTcp = [[_config objectForKey:@"loggingTCP"] boolValue];// ?: true;
    });
    return sharedInstance;
}

/*
-(NSDictionary *)loadSettings
{
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *plistPath = [bundlePath stringByAppendingPathComponent:plistFileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:plistPath]) {
        NSLog(@"[Settings] uic.plist DOES NOT EXIST!");
        return nil;
    }
    NSLog(@"[Settings] Loading uic.plist from %@", plistPath);
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    for (id key in dict) {
        NSLog(@"key=%@ value=%@", key, dict[key]);
    }
    return dict;
}
*/

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

-(NSDictionary *)fetchRemoteConfig:(NSString *)urlString
{
    // TODO: Attempt to load again on failure
    NSLog(@"[Jarvis] [Settings] [DEBUG] Fetching remote config from %@", urlString);
    NSURL *url = [NSURL URLWithString:urlString];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:url];
    if (dict != nil) {
        NSLog(@"[Jarvis] [Settings] [DEBUG] Remote Config: %@", dict);
        return dict;
    }
    NSLog(@"[Jarvis] [Settings] [ERROR] Failed to fetch remote config %@", urlString);
    return nil;
}

@end
