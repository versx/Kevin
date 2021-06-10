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
    // First get the image into your data buffer
    UIColor *color;
    CGImageRef imageRef = [self CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                    bitsPerComponent, bytesPerRow, colorSpace,
                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);

    // Now your rawData contains the image data in the RGBA8888 pixel format.
    NSUInteger byteIndex = (bytesPerRow * y) + x * bytesPerPixel;
    CGFloat alpha = ((CGFloat) rawData[byteIndex + 3] ) / 255.0f;
    CGFloat red   = ((CGFloat) rawData[byteIndex]     ) / 255.0f;
    CGFloat green = ((CGFloat) rawData[byteIndex + 1] ) / 255.0f;
    CGFloat blue  = ((CGFloat) rawData[byteIndex + 2] ) / 255.0f;
    byteIndex += bytesPerPixel;

    color = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    
    //syslog(@"[DEBUG] checking at x: %d y: %d found red: %f green: %f blue: %f", x, y, red, green, blue);
    free(rawData);

    return color;
}

-(UIImage *)resize:(int)x withY:(int)y
{
    CGSize size = CGSizeMake(x, y);
    UIGraphicsBeginImageContext(size);
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *destImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return destImage;
}

-(bool)rgbAtLocation:(DeviceCoordinate *)deviceCoordinate betweenMin:(ColorOffset *)min andMax:(ColorOffset *)max
{
    return [self rgbAtLocation:[deviceCoordinate x]
                         withY:[deviceCoordinate y]
                    betweenMin:min
                        andMax:max
    ];
}

-(bool)rgbAtLocation:(int)x withY:(int)y betweenMin:(ColorOffset *)min andMax:(ColorOffset *)max
{
    UIColor *color = [self getPixelColor:x withY:y];
    const CGFloat* colorComponents = CGColorGetComponents([color CGColor]);
    CGFloat red = colorComponents[0];
    CGFloat green = colorComponents[1];
    CGFloat blue = colorComponents[2];
    /*
    syslog(@"[DEBUG] Checking x=%d y=%d between min [r=%f g=%f b=%f] and max [r=%f g=%f b=%f] pixel=[r=%f g=%f b=%f]",
           x, y,
           [min red], [min green], [min blue],
           [max red], [max green], [max blue],
           red, green, blue
    );
    syslog(@"[DEBUG] Found red: %f green: %f blue: %f", red, green, blue);
    //NSLog(@"[DEBUG] Alpha: %f", CGColorGetAlpha(color));
    */
    bool passed = red   >= [min red]   && red   <= [max red]   && // Red
                  green >= [min green] && green <= [max green] && // Green
                  blue  >= [min blue]  && blue  <= [max blue];    // Blue
    return passed;
}

@end
