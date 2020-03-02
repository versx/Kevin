//
//  Device.h
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIDevice.h>

#include <sys/utsname.h>

@interface Device : NSObject

+(instancetype)sharedInstance;

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
