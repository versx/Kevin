//
//  Utils.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "Utils.h"

@implementation Utils

static double _baseHorizontalAccuracy = 200.0; // in meters
static double _baseVerticalAccuracy = 200.0; // in meters

+(NSNumber *)incrementInt:(NSNumber *)value
{
    return [NSNumber numberWithInt:[value intValue] + 1];
}

+(NSNumber *)decrementInt:(NSNumber *)value
{
    return [NSNumber numberWithInt:[value intValue] - 1];
}

+(CLLocation *)createCoordinate:(double)lat lon:(double)lon
{
    return [Utils createCoordinate:lat
                        lon:lon
     withHorizontalAccuracy:_baseHorizontalAccuracy
           verticalAccuracy:_baseVerticalAccuracy];
}
+(CLLocation *)createCoordinate:(double)lat lon:(double)lon withHorizontalAccuracy:(double)baseHorizontalAccuracy verticalAccuracy:(double)baseVerticalAccuracy
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lon);
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                  altitude:-1
                        horizontalAccuracy:baseHorizontalAccuracy
                          verticalAccuracy:baseVerticalAccuracy
                                 timestamp:[NSDate date]];
    return location;
}

+(void)postRequest:(NSString *)urlString dict:(NSDictionary *)data blocking:(BOOL)blocking completion:(void (^)(NSDictionary* result))completion
{
    //dispatch_async(dispatch_get_main_queue(), ^{
    //    @autoreleasepool {
    __block BOOL done = false;
    __block NSDictionary *resultDict;
    
    // Create the URLSession on the default configuration
    NSURLSessionConfiguration *defaultSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:defaultSessionConfiguration];

    // Setup the request with URL
    //NSLog(@"[Jarvis] [Utils] Sending request to %@ with params %@", urlString, data);
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url
                                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                          timeoutInterval:-1]; // 0.5

    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&error];
    [urlRequest setHTTPBody:postData];
    [urlRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-Length"];

    if ([[Settings sharedInstance] token] != nil &&
        ![[[Settings sharedInstance] token] isEqualToString:@""]) {
        NSString *token = [NSString stringWithFormat:@"Bearer %@", [[Settings sharedInstance] token]];
        [urlRequest addValue:token forHTTPHeaderField:@"Authorization"];
    }
    
    // Convert POST string parameters to data using UTF8 Encoding
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    // Create dataTask
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"[Jarvis] [Utils] postRequest response: %@", responseData);
        [responseData release];
        if (data != nil) { // TODO: Check if json parsed
            NSError *jsonError;
            NSDictionary *resultJson = [NSJSONSerialization JSONObjectWithData:data
                                                                       options:NSJSONReadingMutableContainers
                                                                         error:&jsonError];
            resultDict = resultJson;
            if (!blocking) {
                completion(resultDict);
            }
        } else {
            if (!blocking) {
                completion(nil);
            }
        }
        done = true;
    }];

    // Fire the request
    [dataTask resume];
    if (blocking) {
        while (!done) {
            usleep(1000);
        }
        completion(resultDict);
    }
    //    }
    //});
}

+(NSString *)buildResponse:(NSString *)data withResponseCode:(enum HttpResponseCode)responseCode
{
    NSString *responseHeaders = [Utils responseCodeToString:responseCode];
    NSString *response = [NSString stringWithFormat:@"%@%@", responseHeaders, data];
    return response;
}

+(NSString *)toJsonString:(NSDictionary *)dict withPrettyPrint:(BOOL)prettyPrint
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:(NSJSONWritingOptions)
                    (prettyPrint ? NSJSONWritingPrettyPrinted : 0)
                                                         error:&error];

    if (!jsonData) {
        NSLog(@"[Jarvis] [Utils] %s: error: %@", __func__, error.localizedDescription);
        return @"{}";
    }

    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return json;
}

+(void)touch:(int)x withY:(int)y
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger point = [PTFakeTouch fakeTouchId:[PTFakeTouch getAvailablePointId]
                                           AtPoint:CGPointMake(x, y)
                                    withTouchPhase:UITouchPhaseBegan
        ];
        [PTFakeTouch fakeTouchId:point AtPoint:CGPointMake(x, y) withTouchPhase:UITouchPhaseEnded];
    });
}

+(UIImage *)takeScreenshot
{
    UIScreen *screen = [UIScreen mainScreen];
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    UIGraphicsBeginImageContextWithOptions(screen.bounds.size, false, 0);
    [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:true];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+(NSString *)responseCodeToString:(enum HttpResponseCode)responseCode
{
    NSString *result = nil;
    switch (responseCode) {
        case Success:
            result = HTTP_200_RESPONSE;
            break;
        case BadRequest:
            result = HTTP_400_RESPONSE;
            break;
        case NotFound:
            result = HTTP_404_RESPONSE;
            break;
        default:
            [NSException raise:NSGenericException format:@"Unexpected HttpResponseCode."];
    }
    return result;
}

@end
