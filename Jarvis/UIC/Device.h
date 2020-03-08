//
//  Device.h
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIDevice.h>

#include <sys/utsname.h>

#import "Settings.h"

@interface Device : NSObject

+(instancetype)sharedInstance;

/*
@property (nonatomic, assign) NSString *uuid;
@property (nonatomic, assign) NSString *model;
@property (nonatomic, assign) NSString *osName;
@property (nonatomic, assign) NSString *osVersion;
@property (nonatomic, assign) NSNumber *multiplier;

@property (nonatomic, readwrite, copy) NSString *username;
@property (nonatomic, readwrite, copy) NSString *password;
@property (nonatomic, readwrite, copy) NSString *ptcToken;
@property (nonatomic, readwrite, copy) NSNumber *level;
@property (nonatomic, readwrite, copy) NSNumber *minLevel;
@property (nonatomic, readwrite, copy) NSNumber *maxLevel;
@property (nonatomic, readwrite, assign) BOOL isLoggedIn;
@property (nonatomic, readwrite, assign) BOOL shouldExit;
*/

// TODO: Implement properties correctly
-(NSString *)uuid;
-(NSString *)model;
-(NSString *)osName;
-(NSString *)osVersion;
-(NSNumber *)multiplier;

-(NSString *)username;
-(NSString *)password;
-(NSString *)ptcToken;
-(NSNumber *)level;
-(NSNumber *)minLevel;
-(NSNumber *)maxLevel;
-(BOOL)isLoggedIn;
-(BOOL)shouldExit;


-(void)setUsername:(NSString *)username;
-(void)setPassword:(NSString *)password;
-(void)setPtcToken:(NSString *)ptcToken;
-(void)setLevel:(NSNumber *)level;
-(void)setMinLevel:(NSNumber *)minLevel;
-(void)setMaxLevel:(NSNumber *)maxLevel;
-(void)setIsLoggedIn:(BOOL)isLoggedIn;
-(void)setShouldExit:(BOOL)shouldExit;

@end
