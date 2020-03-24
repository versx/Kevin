//
//  DeviceState.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <CoreLocation/CoreLocation.h>

#import "../States/DeviceState.h"
#import "../UIC/Device.h"
#import "../UIC/Settings.h"

@interface DeviceState : NSObject

+(instancetype)sharedInstance;

@property (nonatomic, readwrite, copy) CLLocation *currentLocation;
@property (nonatomic, readwrite, copy) CLLocation *startupLocation;
@property (nonatomic, readwrite, copy) CLLocation *lastLocation;
@property (nonatomic, readwrite, copy) CLLocation *lastQuestLocation;

@property (nonatomic, readwrite, assign) BOOL gotIV;
@property (nonatomic, readwrite, assign) BOOL gotQuest;
@property (nonatomic, readwrite, assign) BOOL gotQuestEarly;
@property (nonatomic, readwrite, assign) BOOL gotItems;
@property (nonatomic, readwrite, assign) BOOL waitForData;
@property (nonatomic, readwrite, assign) BOOL waitRequiresPokemon;
@property (nonatomic, readwrite, assign) BOOL delayQuest;
@property (nonatomic, readwrite, assign) BOOL skipSpin;
@property (nonatomic, readwrite, assign) BOOL isQuestInit;
@property (nonatomic, readwrite, assign) BOOL ultraQuestSpin;
@property (nonatomic, readwrite, assign) BOOL newCreated;
@property (nonatomic, readwrite, assign) BOOL needsLogout;
//static BOOL _newLogIn;

@property (nonatomic, readwrite, assign) NSNumber *failedGetJobCount;
@property (nonatomic, readwrite, assign) NSNumber *failedCount;
@property (nonatomic, readwrite, assign) NSNumber *noQuestCount;
@property (nonatomic, readwrite, assign) NSNumber *noItemsCount;
@property (nonatomic, readwrite, assign) NSNumber *spinCount;
@property (nonatomic, readwrite, assign) NSNumber *emptyGmoCount;
@property (nonatomic, readwrite, assign) NSNumber *luckyEggsCount;

@property (nonatomic, readwrite, copy) NSDate *firstWarningDate;
@property (nonatomic, readwrite, copy) NSDate *eggStart;
@property (nonatomic, readwrite, copy) NSDate *lastDeployTime;
@property (nonatomic, readwrite, copy) NSDate *lastUpdate;

@property (nonatomic, readwrite, copy) NSString *lastAction;
@property (nonatomic, readwrite, copy) NSString *pokemonEncounterId;
//@property (nonatomic, readwrite, copy) NSString *ptcToken;
@property (nonatomic, readwrite, copy) NSString *targetFortId;


+(void)logout;
+(void)restart;

@end
