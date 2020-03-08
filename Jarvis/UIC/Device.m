//
//  Device.m
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import "Device.h"

@implementation Device

static NSString *_uuid;
static NSString *_model;
static NSString *_osName;
static NSString *_osVersion;
static NSNumber *_multiplier;

static NSString *_username = @"";
static NSString *_password;
static NSString *_ptcToken;
static NSNumber *_level;
static NSNumber *_minLevel;
static NSNumber *_maxLevel;
static BOOL _isLoggedIn;
static BOOL _shouldExit;

// Device information
-(NSString *)uuid {
    return _uuid;
}
-(NSString *)model {
    return _model;
}
-(NSString *)osName {
    return _osName;
}
-(NSString *)osVersion {
    return _osVersion;
}
-(NSNumber *)multiplier {
    return _multiplier;
}

// Device account settings
-(NSString *)username {
    if ([_username isEqualToString:@""]) {
        NSLog(@"[UIC] USERNAME IS NULL");
        //return @"FAIL";
    }
    return _username;
}
-(NSString *)password {
    return _password;
}
-(NSString *)ptcToken {
    return _ptcToken;
}
-(NSNumber *)level {
    return _level;
}
-(NSNumber *)minLevel {
    return _minLevel;
}
-(NSNumber *)maxLevel {
    return _maxLevel;
}
-(BOOL)isLoggedIn {
    return _isLoggedIn;
}
-(BOOL)shouldExit {
    return _shouldExit;
}

-(void)setUsername:(NSString *)username {
    _username = username;
}
-(void)setPassword:(NSString *)password {
    _password = password;
}
-(void)setPtcToken:(NSString *)ptcToken {
    _ptcToken = ptcToken;
}
-(void)setLevel:(NSNumber *)level {
    _level = level;
}
-(void)setMinLevel:(NSNumber *)minLevel {
    _minLevel = minLevel;
}
-(void)setMaxLevel:(NSNumber *)maxLevel {
    _maxLevel = maxLevel;
}
-(void)setIsLoggedIn:(BOOL)isLoggedIn {
    _isLoggedIn = isLoggedIn;
}
-(void)setShouldExit:(BOOL)shouldExit {
    _shouldExit = shouldExit;
}

/*
@synthesize uuid;
@synthesize model;
@synthesize osName;
@synthesize osVersion;
@synthesize multiplier;

@synthesize username;
@synthesize password;
@synthesize ptcToken;
@synthesize level;
@synthesize minLevel;
@synthesize maxLevel;
@synthesize isLoggedIn;
@synthesize shouldExit;
*/

+(Device *)sharedInstance
{
    static Device *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Device alloc] init];
        /*
        [sharedInstance setUuid:[[UIDevice currentDevice] name]];
        [sharedInstance setModel:getNameFromModelIdentifier(getModelIdentifier())];
        [sharedInstance setOsName:[[UIDevice currentDevice] systemName]];
        [sharedInstance setOsVersion:[[UIDevice currentDevice] systemVersion]];
        if ([[sharedInstance model] isEqualToString:@"iPhone 5s"] ||
            [[sharedInstance model] isEqualToString:@"iPhone 6"] ||
            [[sharedInstance model] isEqualToString:@"iPhone 6 Plus"]) {
            [sharedInstance setMultiplier:45];
        } else {
            [sharedInstance setMultiplier:5];
        }
        [sharedInstance setMinLevel:1];
        [sharedInstance setMaxLevel:29];
        */
        _uuid = [[UIDevice currentDevice] name];
        _model = getModelIdentifier(); //[[UIDevice currentDevice] localizedModel];
        _model = getNameFromModelIdentifier(_model);
        _osName = [[UIDevice currentDevice] systemName];
        _osVersion = [[UIDevice currentDevice] systemVersion];
        if ([_model isEqualToString:@"iPhone 5s"] ||
            [_model isEqualToString:@"iPhone 6"] ||
            [_model isEqualToString:@"iPhone 6 Plus"]) {
            _multiplier = @45;
        } else {
            _multiplier = @5;
        }
        _minLevel = @1;
        _maxLevel = @29;
    });
    return sharedInstance;
}

static NSString* getModelIdentifier() {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

static NSString* getNameFromModelIdentifier(NSString* identifier) {
    if ([identifier isEqualToString:@"iPod5,1"]) { return @"iPod touch (5th generation)"; }
    else if ([identifier isEqualToString:@"iPod7,1"]) { return @"iPod touch (6th generation)"; }
    else if ([identifier isEqualToString:@"iPod9,1"]) { return @"iPod touch (7th generation)"; }
    else if ([identifier isEqualToString:@"iPhone3,1"] || [identifier isEqualToString:@"iPhone3,2"] || [identifier isEqualToString:@"iPhone3,3"]) { return @"iPhone 4"; }
    else if ([identifier isEqualToString:@"iPhone4,1"]) { return @"iPhone 4s"; }
    else if ([identifier isEqualToString:@"iPhone5,1"] || [identifier isEqualToString:@"iPhone5,2"]) { return @"iPhone 5"; }
    else if ([identifier isEqualToString:@"iPhone5,3"] || [identifier isEqualToString:@"iPhone5,4"]) { return @"iPhone 5c"; }
    else if ([identifier isEqualToString:@"iPhone6,1"] || [identifier isEqualToString:@"iPhone6,2"]) { return @"iPhone 5s"; }
    else if ([identifier isEqualToString:@"iPhone7,2"]) { return @"iPhone 6"; }
    else if ([identifier isEqualToString:@"iPhone7,1"]) { return @"iPhone 6 Plus"; }
    else if ([identifier isEqualToString:@"iPhone8,1"]) { return @"iPhone 6s"; }
    else if ([identifier isEqualToString:@"iPhone8,2"]) { return @"iPhone 6s Plus"; }
    else if ([identifier isEqualToString:@"iPhone9,1"] || [identifier isEqualToString:@"iPhone9,3"]) { return @"iPhone 7"; }
    else if ([identifier isEqualToString:@"iPhone9,2"] || [identifier isEqualToString:@"iPhone9,4"]) { return @"iPhone 7 Plus"; }
    else if ([identifier isEqualToString:@"iPhone8,4"]) { return @"iPhone SE"; }
    else if ([identifier isEqualToString:@"iPhone10,1"] || [identifier isEqualToString:@"iPhone10,4"]) { return @"iPhone 8"; }
    else if ([identifier isEqualToString:@"iPhone10,2"] || [identifier isEqualToString:@"iPhone10,5"]) { return @"iPhone 8 Plus"; }
    else if ([identifier isEqualToString:@"iPhone10,3"] || [identifier isEqualToString:@"iPhone10,6"]) { return @"iPhone X"; }
    else if ([identifier isEqualToString:@"iPhone11,2"]) { return @"iPhone XS"; }
    else if ([identifier isEqualToString:@"iPhone11,4"] || [identifier isEqualToString:@"iPhone11,6"]) { return @"iPhone XS Max"; }
    else if ([identifier isEqualToString:@"iPhone11,8"]) { return @"iPhone XR"; }
    else if ([identifier isEqualToString:@"iPhone12,1"]) { return @"iPhone 11"; }
    else if ([identifier isEqualToString:@"iPhone12,3"]) { return @"iPhone 11 Pro"; }
    else if ([identifier isEqualToString:@"iPhone12,5"]) { return @"iPhone 11 Pro Max"; }
    else if ([identifier isEqualToString:@"iPad2,1"] || [identifier isEqualToString:@"iPad2,2"] || [identifier isEqualToString:@"iPad2,3"] || [identifier isEqualToString:@"iPad2,4"]) { return @"iPad 2"; }
    else if ([identifier isEqualToString:@"iPad3,1"] || [identifier isEqualToString:@"iPad3,2"] || [identifier isEqualToString:@"iPad3,3"]) { return @"iPad (3rd generation)"; }
    else if ([identifier isEqualToString:@"iPad3,4"] || [identifier isEqualToString:@"iPad3,5"] || [identifier isEqualToString:@"iPad3,6"]) { return @"iPad (4th generation)"; }
    else if ([identifier isEqualToString:@"iPad6,11"] || [identifier isEqualToString:@"iPad6,12"]) { return @"iPad (5th generation)"; }
    else if ([identifier isEqualToString:@"iPad7,5"] || [identifier isEqualToString:@"iPad7,6"]) { return @"iPad (6th generation)"; }
    else if ([identifier isEqualToString:@"iPad7,11"] || [identifier isEqualToString:@"iPad7,12"]) { return @"iPad (7th generation)"; }
    else if ([identifier isEqualToString:@"iPad4,1"] || [identifier isEqualToString:@"iPad4,2"] || [identifier isEqualToString:@"iPad4,3"]) { return @"iPad Air"; }
    else if ([identifier isEqualToString:@"iPad5,3"] || [identifier isEqualToString:@"iPad5,4"]) { return @"iPad Air 2"; }
    else if ([identifier isEqualToString:@"iPad11,4"] || [identifier isEqualToString:@"iPad11,5"]) { return @"iPad Air (3rd generation)"; }
    else if ([identifier isEqualToString:@"iPad2,5"] || [identifier isEqualToString:@"iPad2,6"] || [identifier isEqualToString:@"iPad2,7"]) { return @"iPad mini"; }
    else if ([identifier isEqualToString:@"iPad4,4"] || [identifier isEqualToString:@"iPad4,5"] || [identifier isEqualToString:@"iPad4,6"]) { return @"iPad mini 2"; }
    else if ([identifier isEqualToString:@"iPad4,7"] || [identifier isEqualToString:@"iPad4,8"] || [identifier isEqualToString:@"iPad4,9"]) { return @"iPad mini 3"; }
    else if ([identifier isEqualToString:@"iPad5,1"] || [identifier isEqualToString:@"iPad5,2"]) { return @"iPad mini 4"; }
    else if ([identifier isEqualToString:@"iPad11,1"] || [identifier isEqualToString:@"iPad11,2"]) { return @"iPad mini (5th generation)"; }
    else if ([identifier isEqualToString:@"iPad6,3"] || [identifier isEqualToString:@"iPad6,4"]) { return @"iPad Pro (9.7-inch)"; }
    else if ([identifier isEqualToString:@"iPad6,7"] || [identifier isEqualToString:@"iPad6,8"]) { return @"iPad Pro (12.9-inch)"; }
    else if ([identifier isEqualToString:@"iPad7,1"] || [identifier isEqualToString:@"iPad7,2"]) { return @"iPad Pro (12.9-inch) (2nd generation)"; }
    else if ([identifier isEqualToString:@"iPad7,3"] || [identifier isEqualToString:@"iPad7,4"]) { return @"iPad Pro (10.5-inch)"; }
    else if ([identifier isEqualToString:@"iPad8,1"] || [identifier isEqualToString:@"iPad8,2"] || [identifier isEqualToString:@"iPad8,3"] || [identifier isEqualToString:@"iPad8,4"]) { return @"iPad Pro (11-inch)"; }
    else if ([identifier isEqualToString:@"iPad8,5"] || [identifier isEqualToString:@"iPad8,6"] || [identifier isEqualToString:@"iPad8,7"] || [identifier isEqualToString:@"iPad8,8"]) { return @"iPad Pro (12.9-inch) (3rd generation)"; }
    else if ([identifier isEqualToString:@"AppleTV5,3"]) { return @"Apple TV"; }
    else if ([identifier isEqualToString:@"AppleTV6,2"]) { return @"Apple TV 4K"; }
    else if ([identifier isEqualToString:@"AudioAccessory1,1"]) { return @"HomePod"; }
    else if ([identifier isEqualToString:@"i386"] || [identifier isEqualToString:@"x86_64"]) { return @"Simulator"; }
    return identifier;
}

@end
