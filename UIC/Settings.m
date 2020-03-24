//
//  Settings.m
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import "Settings.h"

@implementation Settings

static NSDictionary *_config;
static BOOL _enableAccountManager;
static NSString *_backendControllerUrl;
static NSString *_backendRawUrl;
static NSString *_token;
static NSNumber *_port;
static NSNumber *_targetMaxDistance;
static NSNumber *_pokemonMaxTime;
static NSNumber *_raidMaxTime;
static NSNumber *_encounterDelay;
static NSNumber *_jitterValue;
static NSNumber *_maxEmptyGMO;
static NSNumber *_maxFailedCount;
static NSNumber *_maxNoQuestCount;
static NSNumber *_maxWarningTimeRaid;
static NSNumber *_minDelayLogout;
static BOOL _ultraQuests;
static BOOL _deployEggs;

static NSString *_loggingUrl;
static NSNumber *_loggingPort;
static BOOL _loggingTls;
static BOOL _loggingTcp; // Use TCP, otherwise UDP protocol

static NSString *plistFileName = @"config.plist";

-(NSDictionary *)config {
    return _config;
}

// TODO: Convert to synthesized properties

-(BOOL)enableAccountManager {
    return _enableAccountManager;
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
-(NSNumber *)port {
    return _port;
}
-(NSNumber *)targetMaxDistance {
    return _targetMaxDistance;
}
-(NSNumber *)pokemonMaxTime {
    return _pokemonMaxTime;
}
-(NSNumber *)raidMaxTime {
    return _raidMaxTime;
}
-(NSNumber *)encounterDelay {
    return _encounterDelay;
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
-(BOOL)ultraQuests {
    return _ultraQuests;
}
-(BOOL)deployEggs {
    return _deployEggs;
}

-(NSString *)loggingUrl {
    return _loggingUrl;
}
-(NSNumber *)loggingPort {
    return _loggingPort;
}
-(BOOL)loggingTls {
    return _loggingTls;
}
-(BOOL)loggingTcp {
    return _loggingTcp;
}

+(Settings *)sharedInstance
{
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
        NSString *remoteConfigUrl = [sharedInstance getRemoteConfigUrl];
        _config = [sharedInstance fetchRemoteConfig:remoteConfigUrl];//[sharedInstance loadSettings];
        _enableAccountManager = [_config[@"enableAccountManager"] boolValue] ?: DEFAULT_ENABLE_ACCOUNT_MANAGER;
        _backendControllerUrl = _config[@"backendControllerURL"];
        _backendRawUrl = _config[@"backendRawURL"];
        _token = _config[@"token"] ?: @"";
        _port = _config[@"port"] ?: DEFAULT_PORT;
        _targetMaxDistance = _config[@"targetMaxDistance"] ?: DEFAULT_TARGET_MAX_DISTANCE;
        _pokemonMaxTime = _config[@"pokemonMaxTime"] ?: DEFAULT_POKEMON_MAX_TIME;
        _raidMaxTime = _config[@"raidMaxTime"] ?: DEFAULT_RAID_MAX_TIME;
        _encounterDelay = _config[@"encounterDelay"] ?: DEFAULT_ENCOUNTER_DELAY;
        _maxEmptyGMO = _config[@"maxEmptyGMO"] ?: DEFAULT_MAX_EMPTY_GMO;
        _maxFailedCount = _config[@"maxFailedCount"] ?: DEFAULT_MAX_FAILED_COUNT;
        _maxNoQuestCount = _config[@"maxNoQuestCount"] ?: DEFAULT_MAX_NO_QUEST_COUNT;
        _maxWarningTimeRaid = _config[@"maxWarningTimeRaid"] ?: DEFAULT_MAX_WARNING_TIME_RAID;
        _minDelayLogout = _config[@"minDelayLogout"] ?: DEFAULT_MIN_DELAY_LOGOUT;
        _ultraQuests = [_config[@"ultraQuests"] boolValue] ?: DEFAULT_ULTRA_QUESTS;
        _deployEggs = [_config[@"deployEggs"] boolValue] ?: DEFAULT_DEPLOY_EGGS;
        
        _loggingUrl = _config[@"LoggingURL"] ?: @""; // TODO: Rename to loggingUrl
        _loggingPort = _config[@"LoggingPort"] ?: @9999; // TODO: Rename to loggingPort
        _loggingTls = [_config[@"LoggingUseTLS"] boolValue] ?: true; // TODO: Rename to loggingTls
        _loggingTcp = [_config[@"loggingTcp"] boolValue] ?: true;
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
