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
    UIColor *color;
    CGImage *cgImage = [self CGImage];
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    const UInt8 *data = CFDataGetBytePtr(pixelData);

    size_t width = CGImageGetWidth(cgImage);
    long components = CGImageGetBitsPerComponent(cgImage);
    //syslog(@"[DEBUG] Components: %ld", components);
    if (components == 16) {
        long pixelInfo = (((width * y) + x) * 8);
        int rValue = 0;
        int gValue = 0;
        int bValue = 0;
        int aValue = 0;
        NSArray *rDataArr = [NSArray arrayWithObjects:@(data[pixelInfo]), @(data[pixelInfo + 1]), nil];
        NSArray *gDataArr = [NSArray arrayWithObjects:@(data[pixelInfo + 2]), @(data[pixelInfo + 3]), nil];
        NSArray *bDataArr = [NSArray arrayWithObjects:@(data[pixelInfo + 4]), @(data[pixelInfo + 5]), nil];
        NSArray *aDataArr = [NSArray arrayWithObjects:@(data[pixelInfo + 6]), @(data[pixelInfo + 7]), nil];
        NSData *rData = [[NSData alloc] initWithBytes:rDataArr length:2];
        NSData *gData = [[NSData alloc] initWithBytes:gDataArr length:2];
        NSData *bData = [[NSData alloc] initWithBytes:bDataArr length:2];
        NSData *aData = [[NSData alloc] initWithBytes:aDataArr length:2];
        [rData getBytes:&rValue length:2];
        [gData getBytes:&gValue length:2];
        [bData getBytes:&bValue length:2];
        [aData getBytes:&aValue length:2];
        UInt8 red   = CGFloat(rValue) / CGFloat(65535.0);
        UInt8 green = CGFloat(gValue) / CGFloat(65535.0);
        UInt8 blue  = CGFloat(bValue) / CGFloat(65535.0);
        UInt8 alpha = CGFloat(aValue) / CGFloat(65535.0);
        CFRelease(pixelData);

        color = [UIColor colorWithRed:red
                                green:green
                                 blue:blue
                                alpha:alpha
        ];
    } else {
        long pixelInfo = (((width * y) + x) * 4); // The image is png
        UInt8 red = data[pixelInfo];
        UInt8 green = data[pixelInfo + 1];
        UInt8 blue = data[pixelInfo + 2];
        UInt8 alpha = data[pixelInfo + 3];
        CFRelease(pixelData);

        color = [UIColor colorWithRed:red   / 255.0f
                                green:green / 255.0f
                                 blue:blue  / 255.0f
                                alpha:alpha / 255.0f
        ];
    }
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
    CGFloat red = colorComponents[2]; // No idea why index of 0 doesn't work.
    CGFloat green = colorComponents[1];
    CGFloat blue = colorComponents[0];
    /*
    syslog(@"[DEBUG] Checking x=%d y=%d between min [r=%f g=%f b=%f] and max [r=%f g=%f b=%f] pixel=[r=%f g=%f b=%f]",
           x, y,
           [min red], [min green], [min blue],
           [max red], [max green], [max blue],
           red, green, blue
    );
    */
    //NSLog(@"[DEBUG] Alpha: %f", CGColorGetAlpha(color));
    bool passed = red   >= [min red]   && red   <= [max red]   && // Red
                  green >= [min green] && green <= [max green] && // Green
                  blue  >= [min blue]  && blue  <= [max blue]; // Blue
    return passed;
}

@end
