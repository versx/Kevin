//
//  UIC.h
//  Jarvis++
//
//  Created by versx on 2/29/20.
//

#import "Consts.h"
#import "Device.h"
#import "../Controllers/JobController.h"
#import "../DeviceConfig/DeviceConfig.h"
#import "../DeviceConfig/DeviceConfigProtocol.h"
#import "../Jarvis++/Jarvis__.h"
#import "../Net/HttpClientConnection.h"
#import "../Settings/Settings.h"

#import <CocoaHTTPServer/HTTPServer.h>
#import <CoreLocation/CoreLocation.h>

#include <string.h>
#include <sys/utsname.h>
#include <math.h>

@interface UIC2 : NSObject

-(void)login;
-(void)startPixelCheckLoop;
-(void)startHeartbeatLoop;

+(BOOL)eggDeploy;

@end
