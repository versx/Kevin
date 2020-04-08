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

-(BOOL)enableAccountManager;
-(NSString *)backendControllerUrl;
-(NSString *)backendRawUrl;
-(NSString *)pixelConfigUrl;
-(NSString *)token;
-(NSNumber *)port;
-(NSNumber *)targetMaxDistance;
-(NSNumber *)pokemonMaxTime;
-(NSNumber *)raidMaxTime;
-(NSNumber *)jitterValue;
-(NSNumber *)maxEmptyGMO;
-(NSNumber *)maxFailedCount;
-(NSNumber *)maxNoQuestCount;
-(NSNumber *)maxWarningTimeRaid;
-(NSNumber *)minDelayLogout;
-(BOOL)ultraQuests;
-(BOOL)deployEggs;
-(BOOL)nearbyTracker;
-(BOOL)autoLogin;

-(NSString *)loggingUrl;
-(NSNumber *)loggingPort;
-(BOOL)loggingTls;
-(BOOL)loggingTcp;


//-(NSDictionary *)loadSettings;
-(NSDictionary *)fetchRemoteConfig:(NSString *)urlString;

@end
