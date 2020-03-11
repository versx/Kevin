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
#import "../Net/HttpServer.h"
#import "../Utilities/Utils.h"

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <PaperTrailLumberjack/RMPaperTrailLogger.h>

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIKit.h>

#include <string.h>
#include <sys/utsname.h>
#include <math.h>

@interface UIC2 : NSObject

-(void)start;
-(void)startUicLoop;

-(NSString *)handleDataRequest:(NSDictionary *)params;
-(NSString *)handleLocationRequest:(NSDictionary *)params;

@end
