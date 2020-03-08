//
//  Utils.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

#import "../Net/HttpResponseCode.h"
#import "../PTFakeTouch/PTFakeTouch.h"

@interface Utils : NSObject

//+(instancetype)sharedInstance;

+(NSNumber *)incrementInt:(NSNumber *)value;
+(NSNumber *)decrementInt:(NSNumber *)value;

+(CLLocation *)createCoordinate:(double)lat lon:(double)lon;
+(CLLocation *)createCoordinate:(double)lat
                            lon:(double)lon
         withHorizontalAccuracy:(double)baseHorizontalAccuracy
               verticalAccuracy:(double)baseVerticalAccuracy;

+(void)postRequest:(NSString *)urlString
                dict:(NSDictionary *)data
            blocking:(BOOL)blocking
          completion:(void (^)(NSDictionary* result))completion;

+(NSString *)buildResponse:(NSString *)data withResponseCode:(enum HttpResponseCode)responseCode;

+(NSString *)toJsonString:(NSDictionary *)dict withPrettyPrint:(BOOL)prettyPrint;

+(void)touch:(int)x withY:(int)y;

+(UIImage *)takeScreenshot;

+(UIColor *)getPixelColor:(int)x withY:(int)y;

@end
