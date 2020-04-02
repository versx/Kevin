//
//  DeviceCoordinate+Extensions.m
//  Jarvis++
//
//  Created by versx on 4/2/20.
//

#import "DeviceCoordinate+Extensions.h"

@implementation DeviceCoordinate (Extensions)

+(BOOL)isAtPixel:(ColorOffset *)min withMax:(ColorOffset *)max
{
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:self
                           betweenMin:min
                               andMax:max
        ];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

@end
