//
//  UIImage+Pixels.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <UIKit/UIKit.h>

@interface UIImage (Pixels)

//-(UIColor *)getPixelColor:(CGFloat *)pos;
-(UIColor *)getPixelColor:(int)x withY:(int)y;

@end
