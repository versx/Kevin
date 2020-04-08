//
//  Device.h
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import <UIKit/UIDevice.h>

#include <sys/utsname.h>

#import "Consts.h"
#import "Settings.h"

@interface Device : NSObject

+(instancetype)sharedInstance;

@property (nonatomic, assign) NSString *uuid;
@property (nonatomic, assign) NSString *model;
@property (nonatomic, assign) NSString *osName;
@property (nonatomic, assign) NSString *osVersion;
@property (nonatomic, assign) NSNumber *delayMultiplier;

@property (nonatomic, readwrite, assign) NSString *ptcToken;
@property (nonatomic, readwrite, assign) NSNumber *level;
@property (nonatomic, readwrite, assign) BOOL isLoggedIn;
@property (nonatomic, readwrite, assign) BOOL shouldExit;

-(BOOL)isOneGbDevice;

-(NSString *)username;
-(void)setUsername:(NSString *)value;
-(NSString *)password;
-(void)setPassword:(NSString *)value;
-(NSNumber *)minLevel;
-(void)setMinLevel:(NSNumber *)value;
-(NSNumber *)maxLevel;
-(void)setMaxLevel:(NSNumber *)value;

-(NSNumber *)luckyEggsCount;
-(void)setLuckyEggsCount:(NSNumber *)value;

-(NSDate *)lastEggDeployTime;
-(void)setLastEggDeployTime:(NSDate *)date;

@end
