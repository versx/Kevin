//
//  UIImage+Pixels.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <UIKit/UIKit.h>

#import "../Device/ColorOffset.h"
#import "../DeviceCoordinate/DeviceCoordinate.h"

@interface UIImage (Pixels)

//-(UIColor *)getPixelColor:(CGFloat *)pos;
-(UIColor *)getPixelColor:(int)x withY:(int)y;

-(UIImage *)resize:(int)x withY:(int)y;

-(bool)rgbAtLocation:(DeviceCoordinate *)deviceCoordinate
          betweenMin:(ColorOffset *)min
              andMax:(ColorOffset *)max;
-(bool)rgbAtLocation:(int)x
               withY:(int)y
          betweenMin:(ColorOffset *)min
              andMax:(ColorOffset *)max;

@end
