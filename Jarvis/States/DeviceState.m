//
//  DeviceState.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "DeviceState.h"

@implementation DeviceState

-(id)init
{
    NSLog(@"[DeviceState] init");
    if ((self = [super init]))
    {
    }
    
    return self;
}

-(void)dealloc
{
    [currentLocation release];
    [startupLocation release];
    [lastLocation release];
    [lastQuestLocation release];
    [firstWarningDate release];
    [super dealloc];
}

+(DeviceState *)sharedInstance
{
    static DeviceState *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DeviceState alloc] init];
    });
    return sharedInstance;
}

@synthesize currentLocation;
@synthesize startupLocation;
@synthesize lastLocation;
@synthesize lastQuestLocation;

@synthesize gotIV;
@synthesize gotQuest;
@synthesize waitForData;
@synthesize waitRequiresPokemon;

@synthesize failedGetJobCount;
@synthesize failedCount;

@synthesize firstWarningDate;

@synthesize pokemonEncounterId;
@synthesize ptcToken;

@end
