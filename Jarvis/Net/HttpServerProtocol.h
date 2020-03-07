//
//  DataReceivedProtocol.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

@protocol HttpServerProtocolDelegate <NSObject>

@required
- (NSString *)handleDataRequest:(NSMutableDictionary *)params;
- (NSString *)handleLocationRequest:(NSMutableDictionary *)params;

@end
