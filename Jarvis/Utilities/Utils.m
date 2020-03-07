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

+(void *)postRequest:(NSString *)urlString dict:(NSDictionary *)data blocking:(BOOL)blocking completion:(void (^)(NSDictionary* result))completion
{
    //dispatch_queue_t socketQueue = [_listenSocket delegateQueue];
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
    BOOL done = false;
    NSDictionary *resultDict;
    
    // Create the URLSession on the default configuration
    NSURLSessionConfiguration *defaultSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:defaultSessionConfiguration];

    // Setup the request with URL
    //NSLog(@"[UIC][HTTP] Sending request to %@ with params %@", urlString, data);
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];

    // Convert POST string parameters to data using UTF8 Encoding
    //NSString *postParams = @"api_key=APIKEY&email=example@example.com&password=password";
    //NSData *postData = [postParams dataUsingEncoding:NSUTF8StringEncoding];

    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&error];
    [urlRequest setHTTPBody:postData];
    [urlRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-Length"];

    //if ([[Settings uuid] isEqualToString:@"test"]) {
    //    [urlRequest addValue:@"Bearer \(token)" forHTTPHeaderField:@"Authorization");
    //}
    
    // Convert POST string parameters to data using UTF8 Encoding
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    // Create dataTask
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"[UIC] postRequest response: %@", responseData);
        if (data != nil) { // TODO: Check if json parsed
            NSError *jsonError;
            NSDictionary *resultJson = [NSJSONSerialization JSONObjectWithData:data
                                                                       options:NSJSONReadingMutableContainers
                                                                         error:&jsonError];
            // TODO: Variable is not assignable (missing __block type specifier) resultDict = resultJson;
            if (!blocking) {
                completion(resultJson);//resultDict);
            }
        } else {
            if (!blocking) {
                completion(nil);
            }
        }
        // TODO: Variable is not assignable (missing __block type specifier) done = true;
    }];

    // Fire the request
    [dataTask resume];
    if (blocking) {
        while (!done) {
            usleep(1000);
        }
        completion(resultDict);
    }
        }
    });
    return 0;
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
        NSLog(@"%s: error: %@", __func__, error.localizedDescription);
        return @"{}";
    }

    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return json;
}

+(void)touch:(int)x withY:(int)y
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger point = [PTFakeTouch fakeTouchId:[PTFakeTouch getAvailablePointId] AtPoint:CGPointMake(x, y) withTouchPhase:UITouchPhaseBegan];
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

+(UIColor *)getPixelColor:(int)x withY:(int)y
{
    return nil;
}

+(NSString *)responseCodeToString:(enum HttpResponseCode)responseCode
{
    NSString *result = nil;
    switch (responseCode) {
        case Success:
            result = @"HTTP/1.1 200 OK\nContent-Type: application/json; charset=utf-8\n\n";
            break;
        case BadRequest:
            result = @"HTTP/1.1 400 OK\nContent-Type: application/json; charset=utf-8\n\n";
            break;
        case NotFound:
            result = @"HTTP/1.1 404 OK\nContent-Type: application/json; charset=utf-8\n\n";
            break;
        default:
            [NSException raise:NSGenericException format:@"Unexpected HttpResponseCode."];
    }
    return result;
}

@end