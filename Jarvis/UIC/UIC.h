//
//  UIC.h
//  Jarvis++
//
//  Created by versx on 2/29/20.
//

@interface UIC2 : NSObject
@property (class, nonatomic, assign, readonly) NSNumber *port;

-(void *)start:(NSNumber *)port;
//- (void *) start_listener:(NSNumber *)port;
//- (void *) handle_request:(void *)pcliefd;

@end
