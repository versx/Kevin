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

+(instancetype)sharedInstance;

/**
* Handle data requests from the `/data` endpoint
*
* @param params POST data as a dictionary
* @return Response string to client
*/
-(NSString *)handleDataRequest:(NSDictionary *)params;

/**
* Handle location requests from the `/loc` endpoint
*
* @return Response string to client
*/
-(NSString *)handleLocationRequest;

/**
* Handle touch requests from the `/touch` endpoint
*
* @param params POST data as a dictionary
* @return Response string to client
*/
-(NSString *)handleTouchRequest:(NSDictionary *)params;

/**
* Handle type requests from the `/type` endpoint
*
* @param params POST data as a dictionary
* @return Response string to client
*/
-(NSString *)handleTypeRequest:(NSDictionary *)params;

/**
* Handle swipe requests from the `/swipe` endpoint
*
* @return Response string to client
*/
-(NSString *)handleSwipeRequest;

/**
* Handle pixel requests from the `/pixel` endpoint
*
* @param params POST data as a dictionary
* @return Response string to client
*/
-(NSString *)handlePixelRequest:(NSDictionary *)params;

/**
* Handle clear requests from the `/clear` endpoint
*
* @return Response string to client
*/
-(NSString *)handleClearRequest;

/**
* Handle config requests from the `/config` endpoint
*
* @return Response string to client
*/
-(NSString *)handleConfigRequest;

/**
* Handle restart requests from the `/restart` endpoint
*
* @return Response string to client
*/
-(NSString *)handleRestartRequest;

-(NSString *)handleAccountRequest;

/**
* Handles test development requests from the `/test` endpoint
*
* @param params POST data as a dictionary
* @return Response string to client
*/
-(NSString *)handleTestRequest:(NSDictionary *)params;

@end
