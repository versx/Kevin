//
//  UIC.h
//  Jarvis++
//
//  Created by versx on 2/29/20.
//

#import "Consts.h"
#import "Device.h"
#import "Settings.h"
#import "../Controllers/JobController.h"
#import "../Device/DeviceConfig.h"
#import "../Net/HttpClientConnection.h"

#import <CocoaHTTPServer/HTTPServer.h>
#import <CoreLocation/CoreLocation.h>

#include <string.h>
#include <sys/utsname.h>
#include <math.h>

@interface UIC2 : NSObject

-(void)start;
-(void)startHeartbeatLoop;
-(void)startUicLoop;

+(NSString *)handleDataRequest:(NSDictionary *)params;
+(NSString *)handleLocationRequest:(NSDictionary *)params;
+(NSString *)handleTouchRequest:(NSDictionary *)params;
+(NSString *)handleTypeRequest:(NSDictionary *)params;
+(NSString *)handleSwipeRequest;
+(NSString *)handlePixelRequest:(NSDictionary *)params;
+(NSString *)handleConfigRequest;
+(NSString *)handleTestRequest:(NSDictionary *)params;

@end
