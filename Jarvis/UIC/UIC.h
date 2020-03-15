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
#import "../Net/HttpClientConnection.h"
#import "../Utilities/Utils.h"

#import <CocoaHTTPServer/HTTPServer.h>
#import <PaperTrailLumberjack/RMPaperTrailLogger.h>

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#include <string.h>
#include <sys/utsname.h>
#include <math.h>

@interface UIC2 : NSObject

-(void)start;
-(void)startUicLoop;

+(NSString *)handleDataRequest:(NSDictionary *)params;
+(NSString *)handleLocationRequest:(NSDictionary *)params;
+(NSString *)handleTouchRequest:(NSDictionary *)params;
+(NSString *)handleConfigRequest;//:(NSDictionary *)params;

@end
