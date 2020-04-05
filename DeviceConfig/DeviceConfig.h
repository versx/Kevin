//
//  DeviceConfig.h
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import <UIKit/UIDevice.h>

#import "DeviceConfigProtocol.h"
//#import "Configs/DeviceIPhoneNormal.h"
//#import "Configs/DeviceIPhonePlus.h"
#import "Configs/DeviceRatio1333.h"
#import "Configs/DeviceRatio1775.h"
#import "../DeviceCoordinate/DeviceCoordinate.h"

@interface DeviceConfig : NSObject

+(id<DeviceConfigProtocol>)sharedInstance;

+(double)tapMultiplier;

@end
