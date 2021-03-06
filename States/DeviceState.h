//
//  DeviceState.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <CoreLocation/CoreLocation.h>

#import "../Extensions/NSString+Extensions.h"
#import "../Settings/Settings.h"
#import "../States/DeviceState.h"
#import "../UIC/Device.h"

@interface DeviceState : NSObject

+(instancetype)sharedInstance;

@property (nonatomic, readwrite, copy) CLLocation *currentLocation;
@property (nonatomic, readwrite, copy) CLLocation *startupLocation;
@property (nonatomic, readwrite, copy) CLLocation *lastLocation;
@property (nonatomic, readwrite, copy) CLLocation *lastQuestLocation;

@property (nonatomic, readwrite, assign) bool gotIV;
@property (nonatomic, readwrite, assign) bool gotQuest;
@property (nonatomic, readwrite, assign) bool gotQuestEarly;
@property (nonatomic, readwrite, assign) bool gotItems;
@property (nonatomic, readwrite, assign) bool waitForData;
@property (nonatomic, readwrite, assign) bool waitRequiresPokemon;
@property (nonatomic, readwrite, assign) bool delayQuest;
@property (nonatomic, readwrite, assign) bool skipSpin;
@property (nonatomic, readwrite, assign) bool isQuestInit;
@property (nonatomic, readwrite, assign) bool newCreated;
@property (nonatomic, readwrite, assign) bool needsLogout;
@property (nonatomic, readwrite, assign) bool isStartup;
//static BOOL _newLogIn;

@property (nonatomic, readwrite, assign) NSNumber *failedGetJobCount;
@property (nonatomic, readwrite, assign) NSNumber *failedCount;
@property (nonatomic, readwrite, assign) NSNumber *noQuestCount;
@property (nonatomic, readwrite, assign) NSNumber *noItemsCount;
@property (nonatomic, readwrite, assign) NSNumber *spinCount;
@property (nonatomic, readwrite, assign) NSNumber *emptyGmoCount;

@property (nonatomic, readwrite, copy) NSDate *firstWarningDate;
@property (nonatomic, readwrite, copy) NSDate *eggStart;
@property (nonatomic, readwrite, copy) NSDate *lastUpdate;

@property (nonatomic, readwrite, copy) NSString *lastAction;
@property (nonatomic, readwrite, copy) NSString *pokemonEncounterId;
//@property (nonatomic, readwrite, copy) NSString *ptcToken;
@property (nonatomic, readwrite, copy) NSString *targetFortId;


+(void)logout;
+(void)logout:(bool)skipRestart;
+(void)restart;
+(void)checkWarning:(NSString *)timestamp;

@end
