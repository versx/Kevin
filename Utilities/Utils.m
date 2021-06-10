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

+(NSNumber *)incrementInt:(NSNumber *)value withAmount:(NSNumber *)amount
{
    return [NSNumber numberWithInt:[value intValue] + [amount intValue]];
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
+(CLLocation *)createCoordinate:(double)lat
                            lon:(double)lon
         withHorizontalAccuracy:(double)baseHorizontalAccuracy
               verticalAccuracy:(double)baseVerticalAccuracy
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lon);
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                  altitude:-1
                        horizontalAccuracy:baseHorizontalAccuracy
                          verticalAccuracy:baseVerticalAccuracy
                                 timestamp:[NSDate date]];
    return location;
}

+(void)postRequest:(NSString *)urlString
              dict:(NSDictionary *)data
          blocking:(BOOL)blocking
        completion:(void (^)(NSDictionary* result))completion
{
    // Create the URLSession on the default configuration
    NSURLSessionConfiguration *defaultSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:defaultSessionConfiguration];

    // Setup the request with URL
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url
                                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                          timeoutInterval:-1]; // 0.5

    // Convert POST string parameters to data using UTF8 Encoding
    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&error];
    [urlRequest setHTTPBody:postData];
    [urlRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-Length"];

    if (![[[Settings sharedInstance] token] isNullOrEmpty]) {
        NSString *token = [NSString stringWithFormat:@"Bearer %@", [[Settings sharedInstance] token]];
        [urlRequest addValue:token forHTTPHeaderField:@"Authorization"];
    }
    
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    // Create dataTask
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            syslog(@"[ERROR] %@ Error: %@", urlString, error);
            return;
        }
        //NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        //syslog(@"[DEBUG] postRequest response: %@", responseData);
        if (data != nil) {
            NSError *jsonError;
            NSDictionary *resultJson = [NSJSONSerialization JSONObjectWithData:data
                                                                       options:NSJSONReadingMutableContainers
                                                                         error:&jsonError];
            //syslog(@"[DEBUG] postRequest resultJson: %@", resultJson);
            completion(resultJson);
        } else {
            completion(nil);
        }
    }];

    // Fire the request
    [dataTask resume];
}

+(NSString *)toJsonString:(NSDictionary *)dict
          withPrettyPrint:(BOOL)prettyPrint
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:(NSJSONWritingOptions)
                    (prettyPrint ? NSJSONWritingPrettyPrinted : 0)
                                                         error:&error];

    if (!jsonData) {
        syslog(@"[ERROR] %@", error);
        return @"{}";
    }

    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return json;
}

+(NSMutableDictionary *)toDictionary:(NSString *)json
{
    NSError *error;
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&error];
    return dict;
}

/*
+(void)touch:(int)x withY:(int)y
{
    @try {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger point = [PTFakeTouch fakeTouchId:[PTFakeTouch getAvailablePointId]
                                               AtPoint:CGPointMake(x, y)
                                        withTouchPhase:UITouchPhaseBegan
            ];
            syslog(@"[DEBUG] touch:x=%d,y=%d point=%ld", x, y, (long)point);
            [PTFakeTouch fakeTouchId:point
                             AtPoint:CGPointMake(x, y)
                      withTouchPhase:UITouchPhaseEnded
            ];
        });
    }
    @catch (NSException *error) {
        syslog(@"[ERROR] Error: %@", error);
    }
}
*/

+(UIImage *)takeScreenshot
{
    //syslog(@"[VERBOSE] takeScreenshot");
    UIScreen *screen = [UIScreen mainScreen];
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    UIGraphicsBeginImageContextWithOptions(screen.bounds.size, false, 0);
    [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:true];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+(void)takeScreenshot:(void (^)(UIImage* image))completion
{
    //syslog(@"[VERBOSE] takeScreenshot with completion handler");
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [self takeScreenshot];
        completion(image);
    });
}

+(void)sendScreenshot
{
    syslog(@"[INFO] sendScreenshot");
    NSString *url = [NSString stringWithFormat:@"%@/api/device/%@/screen",
                     [[Settings sharedInstance] homebaseUrl],
                     [[Device sharedInstance] uuid]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    UIImage *image = [self takeScreenshot];
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);

    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setHTTPShouldHandleCookies:NO];
    [request setTimeoutInterval:60];
    [request setHTTPMethod:@"POST"];
    
    NSString *boundary = @"unique-consistent-string";
    
    // set Content-Type in HTTP header
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    // post body
    NSMutableData *body = [NSMutableData data];
    
    // add params (all params are strings)
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=%@\r\n\r\n", @"imageCaption"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", @"Test"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // add image data
    if (imageData) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=%@; filename=image.jpg\r\n", @"file"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:imageData];
        [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // setting the body of the post to the reqeust
    [request setHTTPBody:body];
    
    // set the content-length
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (data.length > 0) {
            syslog(@"[INFO] Successfully sent screenshot");
        }
    }];
}

+(void)syslog:(NSString *)msg
{
    @try {
        NSString *message = [NSString stringWithFormat:@"[Jarvis] %@", msg];
        NSLog(@"%@", message);
        //return;

        NSString *homebaseUrl = [[Settings sharedInstance] homebaseUrl];
        //NSLog(@"[Jarvis] homebaseUrl: %@", homebaseUrl);
        if ([homebaseUrl isNullOrEmpty]) {
            return;
        }

        NSString *url = [NSString stringWithFormat:@"%@/api/log/new", homebaseUrl];
        NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
        [urlRequest setHTTPMethod:@"POST"];
        [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [urlRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];

        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"uuid"] = [[Device sharedInstance] uuid];
        dict[@"messages"] = @[message];

        NSData *postData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
        [urlRequest setHTTPBody:postData];

        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSLog(@"[Jarvis] Log Error");
            }
        }];
        [dataTask resume];
    }
    @catch (NSException *exception) {
        NSLog(@"[Jarvis] [ERROR] Logs: %@", exception);
    }
}

/*
+(void)syslog:(NSString *)msg
{
    NSString *host = [[Settings sharedInstance] loggingUrl];
    if ([host isNullOrEmpty]) {
        return;
    }
    
    if ([[Settings sharedInstance] loggingTcp]) {
        [self syslogTcp:msg];
        return;
    }

    [self syslogUdp:msg];
    //NSLog(@"[Jarvis] [syslog] <%@:%@:%d>: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), __LINE__, msg);
}

+(void)syslogTcp:(NSString *)msg
{
    @try {
        NSString *host = [[Settings sharedInstance] loggingUrl];
        if ([host isNullOrEmpty]) {
            return;
        }
        GCDAsyncSocket *tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                               delegateQueue:dispatch_get_main_queue()
        ];
        NSError *error = nil;
        NSNumber *port = [[Settings sharedInstance] loggingPort];
        if (![tcpSocket connectToHost:host
                               onPort:[port intValue]
                                error:&error
              ]) {
            NSLog(@"[Jarvis] [Utils] Failed to connect to syslog host %@:%@.", host, port);
            return;
        };
        NSString *date = [Utils iso8601DateTime];
        NSString *uuid = [[Device sharedInstance] uuid];
        NSString *model = [[[Device sharedInstance] model] stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSData *data = [
                        [NSString stringWithFormat:@"<22>1 %@ %@ %@ - - - %@",
                         date,
                         uuid,
                         model,
                         msg]
                     dataUsingEncoding:NSUTF8StringEncoding
        ];
        [tcpSocket writeData:data withTimeout:-1 tag:0];
        [tcpSocket release];
    }
    @catch (NSException *exception) {
        NSLog(@"[Jarvis] [Utils] [ERROR] syslog: %@", exception);
    }
}

+(void)syslogUdp:(NSString *)msg
{
    @try {
        GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
                                                                     delegateQueue:dispatch_get_main_queue()
        ];
        NSString *host = [[Settings sharedInstance] loggingUrl];
        NSNumber *port = [[Settings sharedInstance] loggingPort];
        NSString *date = [Utils iso8601DateTime];
        NSString *uuid = [[Device sharedInstance] uuid];
        NSString *model = [[[Device sharedInstance] model] stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSData *data = [
                        [NSString stringWithFormat:@"<22>1 %@ %@ %@ - - - %@",
                         date,
                         uuid,
                         model,
                         msg]
                     dataUsingEncoding:NSUTF8StringEncoding
        ];
        [udpSocket sendData:data toHost:host port:port withTimeout:-1 tag:0];
        [udpSocket release];
    }
    @catch (NSException *exception) {
        NSLog(@"[Jarvis] [Utils] [ERROR] syslogUdp: %@", exception);
    }
}
*/

+(NSString *)iso8601DateTime
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:enUSPOSIXLocale];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    NSString *date = [formatter stringFromDate:[NSDate date]];
    return date;
}

@end
