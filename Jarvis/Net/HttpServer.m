//
//  HttpServer.m
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "HttpServer.h"

@implementation HttpServer

static GCDAsyncSocket *_listenSocket;
static bool _isListening;
//static NSArray *_validHttpVersions;

-(id)init
{
    NSLog(@"[HTTP] init");
    if ((self = [super init]))
    {
        /*
        _validHttpVersions = @[
            @"HTTP/1.0",
            @"HTTP/1.1",
            @"HTTP/2",
            @"HTTP/3"
        ];
        */
    }
    
    return self;
}

-(void)listen
{
    NSLog(@"[HTTP] listen");
    bool started = false;
    NSNumber *startTryCount = @1;
    // Try to start the HTTP listener, attempt 5 times on failure.
    while (!started) {
        @try {
            [self startListener];
            started = true;
        } @catch(id exception) {
            if ([startTryCount intValue] > 5) {
                NSLog(@"[UIC] Fatal error, failed to start server: %@. Try (%@/5)", exception, startTryCount);
                
                NSLog(@"[UIC] Failed to start server: %@. Try (%@/5). Trying again in 5 seconds.", exception, startTryCount);
                startTryCount = [Utils incrementInt:startTryCount];
                [NSThread sleepForTimeInterval:5];
            }
        }
    }
}

-(void)stop
{
    NSLog(@"[HTTP] stop");
    [_listenSocket disconnect]; // TODO: Check for close/stop method or if disconnect is correct.
}

-(void *)startListener
{
    NSLog(@"[HTTP] startListener");
    _listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    NSNumber *port = [[Settings sharedInstance] port];
    if (![_listenSocket acceptOnPort:[port intValue] error:&error]) {
        NSLog(@"[HTTP] Failed to start webserver listener on port %@:\r\nError:%@", port, error);
    }
    _isListening = true;

    dispatch_queue_t listenerQueue = dispatch_queue_create("listener_queue", NULL);
    dispatch_async(listenerQueue, ^{
        while (_isListening) {
            [_listenSocket readDataWithTimeout:-1 tag:0];
            //[NSThread sleepForTimeInterval:1];
        }
    });

    NSLog(@"[HTTP] Listening at localhost on port %@", port);
    return 0;
}

+(HttpServer *)sharedInstance
{
    static HttpServer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[HttpServer alloc] init];
    });
    return sharedInstance;
}

#pragma GCDAsyncSocket

-(void)socket:(GCDAsyncSocket *)sender didAcceptNewSocket:(nonnull GCDAsyncSocket *)newSocket
{
    // The "sender" parameter is the listenSocket we created.
    // The "newSocket" is a new instance of GCDAsyncSocket.
    // It represents the accepted incoming client connection.

    NSString *host = [newSocket connectedHost];
    UInt16 port = [newSocket connectedPort];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"[UIC] Accepted client %@:%hu", host, port);
        }
    });

    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

-(void)socket:(GCDAsyncSocket *)sender didReadData:(nonnull NSData *)data withTag:(long)tag
{
    //dispatch_async(dispatch_get_main_queue(), ^{
    //    @autoreleasepool {
            //[sender readDataWithTimeout:-1 tag:0];
    NSArray *validHttpVersions = @[
        @"HTTP/1.0",
        @"HTTP/1.1",
        @"HTTP/2",
        @"HTTP/3"
    ];
            NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
            NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
            if (msg) {
                NSLog(@"[UIC] Received data: %@", msg);
                NSArray *split = [msg componentsSeparatedByString:@" "];
                if ([split count] == 3) {
                    NSString *method = split[0];
                    NSString *query = split[1];
                    NSString *httpProtocol = split[2];
                    bool isValidHttpProtocol = [validHttpVersions containsObject:httpProtocol];
                    bool isValidMethod = ([method isEqualToString:@"GET"] || [method isEqualToString:@"POST"]);
                    if (isValidMethod && isValidHttpProtocol) {
                        NSString *response;
                        if ([query hasPrefix:@"/data"]) {
                            NSArray *querySplit = [query componentsSeparatedByString:@"?"];
                            NSMutableDictionary *params = [self parseUrlQueryParameters:querySplit[1]];
                            response = [self.delegate handleDataRequest:params];
                        } else if ([query hasPrefix:@"/loc"]) {
                            NSArray *querySplit = [query componentsSeparatedByString:@"?"];
                            NSMutableDictionary *params = [self parseUrlQueryParameters:querySplit[1]];
                            response = [self.delegate handleLocationRequest:params];
                        } else if ([query hasPrefix:@"/restart"]) {
                            NSLog(@"[UIC] Restart endpoint called, restarting...");
                            // TODO: [self restart];
                        } else if ([query hasPrefix:@"/config"]) {
                            NSMutableString *text = [[NSMutableString alloc] init];
                            NSDictionary *config = [[Settings alloc] loadSettings];
                            for (id key in config) {
                                [text appendFormat:@"%@=%@\n", key, [config objectForKey:key]];
                            }
                            response = [Utils buildResponse:text withResponseCode:Success];
                            //resposne = [NSString stringWithFormat:@"%@%@", _response_200, text];
                        } else if ([query hasPrefix:@"/touch"]) {
                            response = [Utils buildResponse:@":)" withResponseCode:Success];
                            //response = [NSString stringWithFormat:@"%@%@", _response_200, @":)"];
                        } else if ([query hasPrefix:@"/type"]) {
                            response = [Utils buildResponse:@":)" withResponseCode:Success];
                            //response = [NSString stringWithFormat:@"%@%@", _response_200, @":)"];
                        } else if ([query hasPrefix:@"/screen"]) {
                            //UIImage *screenshot = [self takeScreenshot];
                            response = [Utils buildResponse:@":)" withResponseCode:Success];
                            //response = [NSString stringWithFormat:@"%@%@", _response_200, @":)"];
                        } else {
                            NSLog(@"[UIC] Invalid request endpoint.");
                            response = [Utils buildResponse:@"" withResponseCode:NotFound];
                            //response = _response_404;
                        }
                        //NSLog(@"[HTTP] Response: %@", response);
                        [sender writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
                    }
                }
            } else {
                NSLog(@"[UIC] Error converting received data into UTF-8 String");
            }
    //    }
    //});
    //[sender readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

#pragma HTTP Listener

-(void)sendData:(GCDAsyncSocket *)socket data:(NSString *)data
{
    NSString *dataCTRL = [NSString stringWithFormat:@"%@\r\n", data];
    NSData *msg = [dataCTRL dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"[UIC] Sending data: %@", dataCTRL);
    [socket writeData:msg withTimeout:-1 tag:0];
}

-(NSMutableDictionary *)parseUrlQueryParameters:(NSString *)queryParameters
{
    NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
    NSArray *components = [queryParameters componentsSeparatedByString:@"&"];
    for (NSString *pair in components)
    {
        NSArray *pairComponents = [pair componentsSeparatedByString:@"="];
        NSString *key = [[pairComponents firstObject] stringByRemovingPercentEncoding];
        NSString *value = [[pairComponents lastObject] stringByRemovingPercentEncoding];

        [queryStringDictionary setObject:value forKey:key];
    }
    return queryStringDictionary;
}

@end
