//
//  DeviceConfig.m
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import "DeviceConfig.h"

@implementation DeviceConfig

+(id<DeviceConfigProtocol>)sharedInstance
{
    static id<DeviceConfigProtocol> sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        double tapMultiplier = 1.0; // iOS 12 and below
        if (@available(iOS 13.0, *)) {
            tapMultiplier = 0.5; // iOS 13
        }
        double width = [UIScreen mainScreen].bounds.size.width;
        double height = [UIScreen mainScreen].bounds.size.height;
        int ratio = (height / width) * 1000;
        syslog(@"[DEBUG] Size: %fx%f Ratio: %d", width, height, ratio);
        if (ratio >= 1770 && ratio <= 1780) { // iPhones
            switch ((int)width) {
                case 375: // iPhone Normal (6, 6S, 7)
                    syslog(@"[INFO] Normal Phone size detected.");
                    sharedInstance = [[DeviceIPhoneNormal alloc] init:width
                                                               height:height
                                                           multiplier:1.0
                                                        tapMultiplier:tapMultiplier];
                    break;
                case 414: // iPhone Large (6+, 6S+, 7+, 8+)
                    syslog(@"[INFO] Large Phone size detected.");
                    sharedInstance = [[DeviceIPhonePlus alloc] init:width
                                                             height:height
                                                         multiplier:1.5
                                                      tapMultiplier:tapMultiplier];
                    break;
                default: // other iPhones (5S, SE)
                    syslog(@"[INFO] Other Phone size detected.");
                    sharedInstance = [[DeviceRatio1775 alloc] init:width
                                                            height:height
                                                        multiplier:1.0
                                                     tapMultiplier:tapMultiplier];
                    break;
            }
        } else if (ratio >= 1330 && ratio <= 1340) { //iPads
            syslog(@"[FATAL] iPad size detected.");
            sharedInstance = [[DeviceRatio1333 alloc] init:width
                                                    height:height
                                                multiplier:1.0
                                             tapMultiplier:tapMultiplier];
        } else {
            syslog(@"[FATAL] Unsupported Device");
        }
    });
    return sharedInstance;
}

@end
