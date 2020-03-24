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
        return nil;
        long pixelInfo = (((width * y) + x) * 8);
        //int rValue = 0;
        //int gValue = 0;
        //int bValue = 0;
        // TODO: Handle 8 bit images
        //[NSData dataWithBytes:data[pixelInfo] data[pixelInfo + 1] length:2];
        //[NSData dataWithBytes:data[pixelInfo + 2] data[pixelInfo + 3] length:2];
        //[NSData dataWithBytes:data[pixelInfo + 4] data[pixelInfo + 5] length:2];
        //[NSData dataWithBytes:data[pixelInfo + 6] data[pixelInfo + 6] length:2];
        UInt8 red = data[pixelInfo]; // CGFloat(rValue) / CGFloat(65535.0)
        UInt8 green = data[pixelInfo + 1]; // gValue / CGFloat(65535.0)
        UInt8 blue = data[pixelInfo + 2]; // bValue / CGFloat(65535.0)
        UInt8 alpha = data[pixelInfo + 3]; // aValue / CGFloat(65535.0)
        CFRelease(pixelData);

        color = [UIColor colorWithRed:red / 255.0f
                                green:green / 255.0f
                                 blue:blue / 255.0f
                                alpha:alpha / 255.0f
        ];
    } else {
        long pixelInfo = (((width * y) + x) * 4); // The image is png
        UInt8 red = data[pixelInfo];
        UInt8 green = data[pixelInfo + 1];
        UInt8 blue = data[pixelInfo + 2];
        UInt8 alpha = data[pixelInfo + 3];
        CFRelease(pixelData);

        color = [UIColor colorWithRed:red / 255.0f
                                green:green / 255.0f
                                 blue:blue / 255.0f
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

-(NSDictionary *)rgbAtLocation:(int)x withY:(int)y
{
    UIColor *color = [self getPixelColor:x withY:y];
    CGColorRef colorRef = [color CGColor];
    long componentsCount = CGColorGetNumberOfComponents(colorRef);
    if (componentsCount == 4) {
        const CGFloat *components = CGColorGetComponents(colorRef);
        CGFloat red   = components[0];
        CGFloat green = components[1];
        CGFloat blue  = components[2];
        CGFloat alpha = components[3];
        NSDictionary *dict = @{
           @"red": @(red),
           @"green": @(green),
           @"blue": @(blue),
           @"alpha": @(alpha),
        };
        return dict;
    } else if (componentsCount == 3) {
        const CGFloat *components = CGColorGetComponents(colorRef);
        CGFloat red   = components[0];
        CGFloat green = components[1];
        CGFloat blue  = components[2];
        NSDictionary *dict = @{
           @"red": @(red),
           @"green": @(green),
           @"blue": @(blue),
        };
        return dict;
    }
    return nil;
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
    //const CGFloat* minComponents = CGColorGetComponents([min CGColor]);
    //const CGFloat* maxComponents = CGColorGetComponents([max CGColor]);
    syslog(@"[DEBUG] Checking x=%d y=%d between min [r=%f g=%f b=%f] and max [r=%f g=%f b=%f] = [r=%f g=%f b=%f]",
           x, y,
           [min red], [min green], [min blue],
           [max red], [max green], [max blue],
           colorComponents[0], colorComponents[1], colorComponents[2]
    );
    //NSLog(@"[DEBUG] Alpha: %f", CGColorGetAlpha(color));
    bool passed = colorComponents[0] >= [min red] && colorComponents[0] <= [max red] && // Red
                  colorComponents[1] >= [min green] && colorComponents[1] <= [max green] && // Green
                  colorComponents[2] >= [min blue] && colorComponents[2] <= [max blue]; // Blue
    return passed;
}

@end
