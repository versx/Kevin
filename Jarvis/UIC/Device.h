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

@property (nonatomic, assign) NSString *uuid;
@property (nonatomic, assign) NSString *model;
@property (nonatomic, assign) NSString *osName;
@property (nonatomic, assign) NSString *osVersion;
@property (nonatomic, assign) NSNumber *multiplier;

@property (nonatomic, readwrite, assign) NSString *username;
@property (nonatomic, readwrite, assign) NSString *password;
@property (nonatomic, readwrite, assign) NSString *ptcToken;
@property (nonatomic, readwrite, assign) NSNumber *level;
@property (nonatomic, readwrite, assign) NSNumber *minLevel;
@property (nonatomic, readwrite, assign) NSNumber *maxLevel;
@property (nonatomic, readwrite, assign) BOOL isLoggedIn;
@property (nonatomic, readwrite, assign) BOOL shouldExit;

@end
