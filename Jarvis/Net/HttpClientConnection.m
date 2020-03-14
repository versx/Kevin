//
//  HttpClientConnection.m
//  Jarvis++
//
//  Created by versx on 3/13/20.
//

#import "HttpClientConnection.h"

@implementation HttpClientConnection

-(BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    // Add support for POST
    if ([method isEqualToString:@"POST"]) {
        if ([path isEqualToString:@"/"]) {
            // Let's be extra cautious, and make sure the upload isn't 5 gigs
            return requestContentLength < 50;
        }
        if ([path isEqualToString:@"/loc"] ||
            [path isEqualToString:@"/data"] ||
            [path isEqualToString:@"/touch"] ||
            [path isEqualToString:@"/config"]) {
            return YES;
        }
    }
    
    if ([method isEqualToString:@"GET"]) {
        if ([path isEqualToString:@"/touch"] ||
            [path isEqualToString:@"/config"] ||
            [path isEqualToString:@"/restart"] ||
            [path isEqualToString:@"/reboot"]) {
            return YES;
        }
    }
    
    return [super supportsMethod:method atPath:path];
}

-(BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
    // Inform HTTP server that we expect a body to accompany a POST request
    if ([method isEqualToString:@"GET"] ||
        [method isEqualToString:@"POST"]) {
        return YES;
    }
    
    return [super expectsRequestBodyFromMethod:method atPath:path];
}

-(NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    NSLog(@"[Jarvis] [HTTP] httpResponseForMethod: Method: %@ Path: %@", method, path);
    
    if ([method isEqualToString:@"POST"]) {
        //NSLog(@"[Jarvis] [HTTP] %@[%p]: postContentLength: %qu", THIS_FILE, self, requestContentLength);
        NSDictionary *json;
        NSString *postStr = nil;
        NSError *error = nil;
        NSData *postData = [request body];
        if (postData) {
            postStr = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            json = [NSJSONSerialization JSONObjectWithData:postData
                                                    options:kNilOptions
                                                      error:&error
            ];
        }
        NSLog(@"[Jarvis] [HTTP] %@[%p]: postStr: %@", THIS_FILE, self, postStr);
        NSString *response;
        if ([path isEqualToString:@"/loc"]) {
            response = [UIC2 handleLocationRequest:json];
        } else if ([path isEqualToString:@"/data"]) {
            response = [UIC2 handleDataRequest:json];
        } else if ([path isEqualToString:@"/config"]) {
            response = [UIC2 handleConfigRequest];
        } else if ([path isEqualToString:@"/touch"]) {
            response = [UIC2 handleTouchRequest:json];
        }
        NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
        return [[HTTPDataResponse alloc] initWithData:responseData];
    } else {
        NSString *response;
        if ([path isEqualToString:@"/config"]) {
            response = [UIC2 handleConfigRequest];
        } else if ([path isEqualToString:@"/touch"]) {
            //response = [UIC2 handleTouchRequest:json];
        } else if ([path isEqualToString:@"/restart"] ||
                   [path isEqualToString:@"/reboot"]) {
            response = @"OK";
            [DeviceState restart];
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
    /*
    BOOL result = [request appendData:postDataChunk];
    if (!result) {
        NSLog(@"[Jarvis] [HTTP] %@[%p]: %@ - Couldn't append bytes!", THIS_FILE, self, THIS_METHOD);
    }
    */
}

@end
