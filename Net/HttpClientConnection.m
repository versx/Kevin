//
//  HttpClientConnection.m
//  Jarvis++
//
//  Created by versx on 3/13/20.
//

#import "HttpClientConnection.h"

@implementation HttpClientConnection

//static NSArray *ValidGetEndpoints;
//static NSArray *ValidPostEndpoints;

-(id)init
{
    if ((self = [super init])) {
        /*
        ValidGetEndpoints = @[
            @"/account",
            @"/clear",
            @"/config",
            @"/loc",
            @"/reboot",
            @"/restart",
            @"/screen",
            @"/system_info"
        ];
        ValidPostEndpoints = @[
            @"/data",
            @"/loc",
            @"/pixel",
            @"/touch",
            @"/type",
            @"/test"
        ];
        */
    }
    return self;
}

-(BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    // Add support for POST
    if ([method isEqualToString:@"POST"]) {
        /*
        if ([ValidPostEndpoints containsObject:path]) {
            return YES;
        }
        */
        if ([path isEqualToString:@"/loc"] ||
            [path isEqualToString:@"/data"] ||
            [path isEqualToString:@"/touch"] ||
            [path isEqualToString:@"/type"] ||
            [path isEqualToString:@"/pixel"] ||
            [path isEqualToString:@"/test"]) {
            // Let's be extra cautious, and make sure the upload isn't 5 gigs
            //return requestContentLength < (10 * 1024 * 1024); // 10 MB
            return YES;
        }
    }
    
    if ([method isEqualToString:@"GET"]) {
        /*
        if ([ValidGetEndpoints containsObject:path]) {
            return YES;
        }
        */
        if ([path isEqualToString:@"/loc"] ||
            [path isEqualToString:@"/config"] ||
            [path isEqualToString:@"/restart"] ||
            [path isEqualToString:@"/reboot"] ||
            [path isEqualToString:@"/clear"] ||
            [path isEqualToString:@"/account"] ||
            [path isEqualToString:@"/screen"] ||
            [path isEqualToString:@"/system_info"]) {
            return YES;
        }
    }
    
    return [super supportsMethod:method atPath:path];
}

-(NSData *)preprocessResponse:(HTTPMessage *)response
{
    //syslog(@"[DEBUG] Request URI: %@", [self requestURI]);
    [response setHeaderField:@"Access-Control-Allow-Origin" value:@"*"];
    if ([[self requestURI] isEqualToString:@"/screen"]) {
        [response setHeaderField:@"Accept" value:@"image/jpeg"];
        [response setHeaderField:@"Content-Type" value:@"image/jpeg"];
    } else {
        [response setHeaderField:@"Accept" value:@"application/json"];
        [response setHeaderField:@"Content-Type" value:@"application/json"];
    }
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
        //syslog(@"[DEBUG] postStr: %@", postStr);
        NSString *response;
        if ([path isEqualToString:@"/loc"]) {
            response = [[RequestController sharedInstance] handleLocationRequest];
        } else if ([path isEqualToString:@"/data"]) {
            response = [[RequestController sharedInstance] handleDataRequest:json];
        } else if ([path isEqualToString:@"/touch"]) {
            response = [[RequestController sharedInstance] handleTouchRequest:json];
        } else if ([path isEqualToString:@"/type"]) {
            response = [[RequestController sharedInstance] handleTypeRequest:json];
        } else if ([path isEqualToString:@"/pixel"]) {
            response = [[RequestController sharedInstance] handlePixelRequest:json];
        } else if ([path isEqualToString:@"/test"]) {
            response = [[RequestController sharedInstance] handleTestRequest:json];
        }
        NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
        return [[HTTPDataResponse alloc] initWithData:responseData];
    } else {
        NSString *response;
        if ([path isEqualToString:@"/loc"]) {
            response = [[RequestController sharedInstance] handleLocationRequest];
        } else if ([path isEqualToString:@"/config"]) {
            response = [[RequestController sharedInstance] handleConfigRequest];
        } else if ([path isEqualToString:@"/restart"] ||
                   [path isEqualToString:@"/reboot"]) {
            response = [[RequestController sharedInstance] handleRestartRequest];
        } else if ([path isEqualToString:@"/clear"]) {
            response = [[RequestController sharedInstance] handleClearRequest];
        } else if ([path isEqualToString:@"/account"]) {
            response = [[RequestController sharedInstance] handleAccountRequest];
        } else if ([path isEqualToString:@"/screen"]) {
            //NSData *imgData = [[RequestController sharedInstance] handleScreenRequest];
            //return [[HTTPDataResponse alloc] initWithData:imgData];
            response = [[RequestController sharedInstance] handleScreenRequest];
        } else if ([path isEqualToString:@"/system_info"]) {
            response = [[RequestController sharedInstance] handleSystemInfoRequest];
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
