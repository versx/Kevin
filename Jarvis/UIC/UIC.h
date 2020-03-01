//
//  UIC.h
//  Jarvis++
//
//  Created by versx on 2/29/20.
//

@interface UIC2 : NSObject
@property (class, nonatomic, assign, readonly) NSNumber *port;

-(void *)start:(NSNumber *)port;
-(void *)startListener;
-(void *)startUicLoop;
-(NSString *)handleDataRequest:(NSDictionary *)params;
-(NSString *)handleLocationRequest:(NSDictionary *)params;
-(void *)logout;
-(void *)restart;

@end
