//
//  HttpClientConnection.m
//  Jarvis++
//
//  Created by versx on 3/13/20.
//

#import "HttpClientConnection.h"

@implementation HttpClientConnection

/* Unused, make sure of them.
// HTTP endpoints
NSString * VALID_GET_ENDPOINTS[5] = {
    @"/loc",
    @"/config",
    @"/restart",
    @"/reboot",
    @"/clear"
};
NSString * VALID_POST_ENDPOINTS[7] = {
    @"/loc",
    @"/data",
    @"/touch",
    @"/type",
    @"/swipe",
    @"/pixel",
    @"/test"
};
*/

-(BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    // Add support for POST
    if ([method isEqualToString:@"POST"]) {
        if ([path isEqualToString:@"/loc"] ||
            [path isEqualToString:@"/data"] ||
            [path isEqualToString:@"/touch"] ||
            [path isEqualToString:@"/type"] ||
            [path isEqualToString:@"/swipe"] ||
            [path isEqualToString:@"/pixel"] ||
            [path isEqualToString:@"/test"]) {
            // Let's be extra cautious, and make sure the upload isn't 5 gigs
            //return requestContentLength < 50;
            return YES;
        }
    }
    
    if ([method isEqualToString:@"GET"]) {
        if ([path isEqualToString:@"/loc"] ||
            [path isEqualToString:@"/config"] ||
            [path isEqualToString:@"/restart"] ||
            [path isEqualToString:@"/reboot"] ||
            [path isEqualToString:@"/clear"]) {
            return YES;
        }
    }
    
    return [super supportsMethod:method atPath:path];
}

-(NSData *)preprocessResponse:(HTTPMessage *)response
{
    [response setHeaderField:@"Accept" value:@"application/json"];
    [response setHeaderField:@"Content-Type" value:@"application/json"];
    return [response messageData];
}

-(BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
    // Inform HTTP server that we expect a body to accompany a POST request
    if ([method isEqualToString:@"POST"]) {
        return YES;
    }
    return [super expectsRequestBodyFromMethod:method atPath:path];
}

-(NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    //syslog(@"[INFO] %@ %@", method, path);
    
    if ([method isEqualToString:@"POST"]) {
        NSDictionary *json;
        NSString *postStr = nil;
        NSError *error = nil;
        NSData *postData = [request body];
        if (postData) {
            postStr = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            json = [NSJSONSerialization JSONObjectWithData:postData
                                                    options:kNilOptions
                                                      error:&error];
        }
        syslog(@"[DEBUG] postStr: %@", postStr);
        NSString *response;
        if ([path isEqualToString:@"/loc"]) {
            response = [[RequestController sharedInstance] handleLocationRequest]; // [UIC2 handleLocationRequest];
        } else if ([path isEqualToString:@"/data"]) {
            response = [[RequestController sharedInstance] handleDataRequest:json]; //[UIC2 handleDataRequest:json];
        } else if ([path isEqualToString:@"/touch"]) {
            response = [[RequestController sharedInstance] handleTouchRequest:json]; //[UIC2 handleTouchRequest:json];
        } else if ([path isEqualToString:@"/type"]) {
            response = [[RequestController sharedInstance] handleTypeRequest:json]; //[UIC2 handleTypeRequest:json];
        } else if ([path isEqualToString:@"/swipe"]) {
            response = [[RequestController sharedInstance] handleSwipeRequest]; //[UIC2 handleSwipeRequest];
        } else if ([path isEqualToString:@"/pixel"]) {
            response = [[RequestController sharedInstance] handlePixelRequest:json]; //[UIC2 handlePixelRequest:json];
        } else if ([path isEqualToString:@"/test"]) {
            response = [[RequestController sharedInstance] handleTestRequest:json]; //[UIC2 handleTestRequest:json];
        }
        NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
        return [[HTTPDataResponse alloc] initWithData:responseData];
    } else {
        NSString *response;
        if ([path isEqualToString:@"/loc"]) {
            response = [[RequestController sharedInstance] handleLocationRequest]; //[UIC2 handleLocationRequest];
        } else if ([path isEqualToString:@"/config"]) {
            response = [[RequestController sharedInstance] handleConfigRequest]; //[UIC2 handleConfigRequest];
        } else if ([path isEqualToString:@"/restart"] || // TODO: Restart app?
                   [path isEqualToString:@"/reboot"]) { // TODO: Reboot phone?
            response = JSON_OK;
            [DeviceState restart];
        } else if ([path isEqualToString:@"/clear"]) {
            syslog(@"[INFO] Clearing user defaults");
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:LOGIN_USER_DEFAULT_KEY];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:TOKEN_USER_DEFAULT_KEY];
            response = JSON_OK;
        }
        NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
        return [[HTTPDataResponse alloc] initWithData:responseData];
    }
    
    return [super httpResponseForMethod:method URI:path];
}

-(void)prepareForBodyWithSize:(UInt64)contentLength
{
    // If we supported large uploads,
    // we might use this method to create/open files, allocate memory, etc.
}

-(void)processBodyData:(NSData *)postDataChunk
{
    // Remember: In order to support LARGE POST uploads, the data is read in chunks.
    // This prevents a 50 MB upload from being stored in RAM.
    // The size of the chunks are limited by the POST_CHUNKSIZE definition.
    // Therefore, this method may be called multiple times for the same POST request.
    
    [request appendData:postDataChunk];
}

@end
