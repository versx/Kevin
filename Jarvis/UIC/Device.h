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

@end
