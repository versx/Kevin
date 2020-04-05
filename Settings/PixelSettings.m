//
//  PixelSettings.m
//  Jarvis++
//
//  Created by versx on 3/30/20.
//

#import "PixelSettings.h"

@implementation PixelSettings

+(PixelSettings *)sharedInstance
{
    static PixelSettings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PixelSettings alloc] init];
    });
    return sharedInstance;
}

@end
