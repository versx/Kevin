//
//  UIC.h
//  Jarvis++
//
//  Created by versx on 2/29/20.
//

@interface UIC2 : NSObject
@property (class, nonatomic, assign, readonly) NSNumber *port;

-(void *)start:(NSNumber *)port;
-(void *)start_listener;
-(NSString *)handle_data:(NSDictionary *)params;
-(NSString *)handle_location:(NSDictionary *)params;

@end
