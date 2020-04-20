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

-(NSString *)homebaseUrl;
-(NSString *)backendControllerUrl;
-(NSString *)backendRawUrl;
-(NSString *)pixelConfigUrl;
-(NSString *)token;
-(int)port;
-(int)targetMaxDistance;
-(int)heartbeatMaxTime;
-(int)pokemonMaxTime;
-(int)raidMaxTime;
-(double)jitterValue;
-(int)maxEmptyGMO;
-(int)maxFailedCount;
-(int)maxNoQuestCount;
-(int)maxWarningTimeRaid;
-(int)minDelayLogout;
-(bool)enableAccountManager;
-(bool)deployEggs;
-(bool)nearbyTracker;
-(bool)autoLogin;
-(bool)ultraIV;
-(bool)ultraQuests;
-(bool)allowWarnedAccounts;

-(NSString *)loggingUrl;
-(int)loggingPort;
-(bool)loggingTls;
-(bool)loggingTcp;

-(bool)gotConfig;


//-(NSDictionary *)loadSettings;
-(NSString *)getRemoteConfigUrl;
-(NSDictionary *)fetchJsonConfig:(NSString *)urlString;

@end
