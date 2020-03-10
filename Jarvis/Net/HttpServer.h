//
//  HttpServer.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "HttpResponseCode.h"
#import "HttpServer.h"
#import "HttpServerProtocol.h"
#import "../States/DeviceState.h"
#import "../UIC/Device.h"
#import "../UIC/Settings.h"
#import "../Utilities/Utils.h"

@interface HttpServer : NSObject {
    id <HttpServerProtocolDelegate> _delegate;
}

@property (nonatomic,strong) id delegate;

+(instancetype)sharedInstance;

-(void)listen;
-(void)stop;
//-(void)sendData:(GCDAsyncSocket *)socket data:(NSString *)data;

@end
