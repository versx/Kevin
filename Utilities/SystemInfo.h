//
//  SystemInfo.h
//  Jarvis++
//
//  Created by versx on 4/6/20.
//

#import <mach/mach.h>

@interface SystemInfo : NSObject

+(instancetype)sharedInstance;

@property (nonatomic, assign) NSNumber *cpuUsage;
@property (nonatomic, assign) NSUInteger processorCount;
@property (nonatomic, assign) NSProcessInfoThermalState thermalState;
@property (nonatomic, assign) NSTimeInterval systemUptime;

@property (nonatomic, assign) NSNumber *totalMemory;
@property (nonatomic, assign) NSNumber *freeMemory;
@property (nonatomic, assign) NSNumber *usedMemory;

@property (nonatomic, assign) NSNumber *totalSpace;
@property (nonatomic, assign) NSNumber *freeSpace;
@property (nonatomic, assign) NSNumber *usedSpace;

+(NSString *)formatBytes:(long)bytes;
+(NSString *)formatThermalState:(NSProcessInfoThermalState)state;
+(NSString *)formatTimeInterval:(NSTimeInterval)timeInterval;

@end
