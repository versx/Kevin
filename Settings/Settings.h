//
//  Settings.h
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

#import "Consts.h"
#import "../States/DeviceState.h"

@interface Settings : NSObject

+(instancetype)sharedInstance;

-(NSDictionary *)config;

-(bool)enableAccountManager;
-(NSString *)backendControllerUrl;
-(NSString *)backendRawUrl;
-(NSString *)pixelConfigUrl;
-(NSString *)token;
-(NSNumber *)port;
-(NSNumber *)targetMaxDistance;
-(NSNumber *)heartbeatMaxTime;
-(NSNumber *)pokemonMaxTime;
-(NSNumber *)raidMaxTime;
-(NSNumber *)jitterValue;
-(NSNumber *)maxEmptyGMO;
-(NSNumber *)maxFailedCount;
-(NSNumber *)maxNoQuestCount;
-(NSNumber *)maxWarningTimeRaid;
-(NSNumber *)minDelayLogout;
-(bool)ultraIV;
-(bool)ultraQuests;
-(bool)deployEggs;
-(bool)nearbyTracker;
-(bool)autoLogin;

-(NSString *)loggingUrl;
-(NSNumber *)loggingPort;
-(bool)loggingTls;
-(bool)loggingTcp;


//-(NSDictionary *)loadSettings;
-(NSDictionary *)fetchRemoteConfig:(NSString *)urlString;

@end
