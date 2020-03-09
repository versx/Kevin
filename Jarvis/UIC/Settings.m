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

static NSString *plistFileName = @"uic.plist";

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

+(Settings *)sharedInstance
{
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
        _config = [sharedInstance loadSettings];
        _enableAccountManager = _config[@"enableAccountManager"] ?: false;
        _backendControllerUrl = _config[@"backendControllerURL"];
        _backendRawUrl = _config[@"backendRawURL"];
        _token = _config[@"token"] ?: @"";
        _port = _config[@"port"] ?: @8080;
        _targetMaxDistance = _config[@"targetMaxDistance"] ?: @250.0;
        _pokemonMaxTime = _config[@"pokemonMaxTime"] ?: @25.0;
        _raidMaxTime = _config[@"raidMaxTime"] ?: @25.0;
        _encounterDelay = _config[@"encounterDelay"] ?: @0.0;
        _maxEmptyGMO = _config[@"maxEmptyGMO"] ?: @50;
        _maxFailedCount = _config[@"maxEmptyGMO"] ?: @5;
        _maxNoQuestCount = _config[@"maxNoQuestCount"] ?: @5;
        _maxWarningTimeRaid = _config[@"maxWarningTimeRaid"] ?: @432000;
        _minDelayLogout = _config[@"minDelayLogout"] ?: @180.0;
        _ultraQuests = _config[@"ultraQuests"] ?: false;
        _deployEggs = _config[@"deployEggs"] ?: false;
    });
    return sharedInstance;
}

-(NSDictionary *)loadSettings {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *plistPath = [bundlePath stringByAppendingPathComponent:plistFileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:plistPath]) {
        NSLog(@"[UIC] uic.plist DOES NOT EXIST!");
        return nil;
    }
    NSLog(@"[UIC] Loading uic.plist from %@", plistPath);
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    for (id key in dict) {
        NSLog(@"key=%@ value=%@", key, dict[key]);
    }
    return dict;
}

@end
