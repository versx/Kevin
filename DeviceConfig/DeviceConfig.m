//
//  DeviceConfig.m
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import "DeviceConfig.h"
#import "DeviceIPhonePlus.h"
#import "DeviceIPhoneNormal.h"

@implementation DeviceConfig

+(double)tapMultiplier
{
    double width = [UIScreen mainScreen].bounds.size.width;
    double tapMultiplier = 1.0; // iOS 12 and below
    if (@available(iOS 13.0, *)) {
        tapMultiplier = 0.5; // iOS 13
    }
    if (width == 414) { // Plus devices are all 1/3 with this setup
        tapMultiplier = 0.33333;
    }
    // For whatever reason 5S with iOS 12 support uses 0.5?
    NSString *model = [[Device sharedInstance] model];
    if ([model isEqualToString:@"iPhone SE"] ||
        [model isEqualToString:@"iPhone 5s"] ||
        [model isEqualToString:@"iPhone 6"] ||
        [model isEqualToString:@"iPhone 6s"]) {
        tapMultiplier = 0.5;
    }
    return tapMultiplier;
}

+(id<DeviceConfigProtocol>)sharedInstance
{
    static id<DeviceConfigProtocol> sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self getDeviceConfig];
    });
    return sharedInstance;
}

+(id<DeviceConfigProtocol>)getDeviceConfig
{
    id<DeviceConfigProtocol> deviceConfig;
    double width = [UIScreen mainScreen].bounds.size.width;
    double height = [UIScreen mainScreen].bounds.size.height;
    double tapMultiplier = [self tapMultiplier];
    int ratio = (height / width) * 1000;
    if (ratio >= 1770 && ratio <= 1780) { // iPhones
        switch ((int)width) {
            case 375: // iPhone Normal (6, 6S, 7)
                syslog(@"[INFO] Normal Phone size detected (Width: %f, Height: %f, Ratio: %d)",
                       width, height, ratio);
                deviceConfig = [[DeviceIPhoneNormal alloc] init:width
                                                         height:height
                                                     multiplier:1.0
                                                  tapMultiplier:tapMultiplier];
                break;
            case 414: // iPhone Large (6+, 6S+, 7+, 8+)
                syslog(@"[INFO] Large Phone size detected (Width: %f, Height: %f, Ratio: %d)",
                       width, height, ratio);
                deviceConfig = [[DeviceIPhonePlus alloc] init:width
                                                       height:height
                                                   multiplier:1.5
                                                tapMultiplier:tapMultiplier];
                break;
            default: // other iPhones (5S, SE)
                syslog(@"[INFO] Other Phone size detected (Width: %f, Height: %f, Ratio: %d)",
                       width, height, ratio);
                deviceConfig = [[DeviceRatio1775 alloc] init:width
                                                      height:height
                                                  multiplier:1.0
                                               tapMultiplier:tapMultiplier];
                break;
        }
    } else if (ratio >= 1330 && ratio <= 1340) { // iPads
        syslog(@"[INFO] iPad size detected (Width: %f, Height: %f, Ratio: %d)",
               width, height, ratio);
        deviceConfig = [[DeviceRatio1333 alloc] init:width
                                              height:height
                                          multiplier:1.0
                                       tapMultiplier:tapMultiplier];
    } else {
        syslog(@"[FATAL] Unsupported Device (Width: %f, Height: %f, Ratio: %d)",
               width, height, ratio);
    }
    return deviceConfig;
}

@end
