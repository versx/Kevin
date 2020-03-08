//
//  UIImage+Pixels.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "UIImage+Pixels.h"

@implementation UIImage (Pixels)

-(UIColor *)getPixelColor:(int)x withY:(int)y
{
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(self.CGImage));
    const UInt8 *data = CFDataGetBytePtr(pixelData);

    int pixelInfo (((self.size.width * y) + x) * 4); // The image is png
    UInt8 red = data[pixelInfo];
    UInt8 green = data[pixelInfo + 1];
    UInt8 blue = data[pixelInfo + 2];
    UInt8 alpha = data[pixelInfo + 3];
    CFRelease(pixelData);
    
    UIColor *color = [UIColor colorWithRed:red / 255.0f
                                     green:green / 255.0f
                                      blue:blue / 255.0f
                                     alpha:alpha / 255.0f
    ];
    return color;
}

@end
