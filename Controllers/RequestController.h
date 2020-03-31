//
//  RequestController.h
//  Jarvis++
//
//  Created by versx on 3/29/20.
//

#import "JobController.h"
#import "../Extensions/UIImage+Pixels.h"
#import "../States/DeviceState.h"
#import "../UIC/Consts.h"
#import "../UIC/JarvisTestCase.h"

@interface RequestController : NSObject

+(RequestController *)sharedInstance;

-(NSString *)handleDataRequest:(NSDictionary *)params;
-(NSString *)handleLocationRequest;
-(NSString *)handleTouchRequest:(NSDictionary *)params;
-(NSString *)handleTypeRequest:(NSDictionary *)params;
-(NSString *)handleSwipeRequest;
-(NSString *)handlePixelRequest:(NSDictionary *)params;
-(NSString *)handleClearRequest;
-(NSString *)handleConfigRequest;
-(NSString *)handleRestartRequest;
-(NSString *)handleTestRequest:(NSDictionary *)params;

@end
