//
//  UIImage+Pixels.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <UIKit/UIKit.h>

#import "../DeviceConfig/ColorOffset.h"
#import "../DeviceCoordinate/DeviceCoordinate.h"

@interface UIImage (Pixels)

-(UIColor *)getPixelColor:(int)x withY:(int)y;

// Can probably remove, not used currently.
-(UIImage *)resize:(int)x withY:(int)y;

-(bool)rgbAtLocation:(DeviceCoordinate *)deviceCoordinate
          betweenMin:(ColorOffset *)min
              andMax:(ColorOffset *)max;
-(bool)rgbAtLocation:(int)x
               withY:(int)y
          betweenMin:(ColorOffset *)min
              andMax:(ColorOffset *)max;

@end
