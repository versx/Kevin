//
//  Settings.m
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import "Settings.h"

@implementation Settings

static NSDictionary *_config;
static NSString *plistFileName = @"uic.plist";

-(NSDictionary *)config {
    return _config;
}

+(Settings *)sharedInstance
{
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
        _config = [sharedInstance loadSettings];
    });
    return sharedInstance;
}

-(NSDictionary *)loadSettings {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *plistPath = [bundlePath stringByAppendingPathComponent:plistFileName];
    
    NSLog(@"[UIC] Loading uic.plist from %@", plistPath);
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:plistPath]) {
        NSLog(@"[UIC] uic.plist DOES NOT EXIST!");
        return dict;
    }
    NSLog(@"[UIC] uic.plist Settings");
    for (id key in dict) {
        NSLog(@"key=%@ value=%@", key, [dict objectForKey:key]);
    }
    return dict;
}

@end
