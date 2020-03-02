//
//  RequestController.h
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

@interface RequestController : NSObject

+(instancetype)sharedInstance;

-(NSString *)handleDataRequest:(NSDictionary *)data;
-(NSString *)handleLocationRequest:(NSDictionary *)data;

@end
