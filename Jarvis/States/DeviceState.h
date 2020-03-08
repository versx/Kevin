//
//  DeviceState.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

@interface DeviceState : NSObject

+(instancetype)sharedInstance;

@property (nonatomic, readwrite, copy) CLLocation *currentLocation;
@property (nonatomic, readwrite, copy) CLLocation *startupLocation;
@property (nonatomic, readwrite, copy) CLLocation *lastLocation;
@property (nonatomic, readwrite, copy) CLLocation *lastQuestLocation;

@property (nonatomic, readwrite, assign) BOOL gotIV;
@property (nonatomic, readwrite, assign) BOOL gotQuest;
@property (nonatomic, readwrite, assign) BOOL waitForData;
@property (nonatomic, readwrite, assign) BOOL waitRequiresPokemon;

@property (nonatomic, readwrite, assign) NSNumber *failedGetJobCount;
@property (nonatomic, readwrite, assign) NSNumber *failedCount;

@property (nonatomic, readwrite, copy) NSDate *firstWarningDate;

@property (nonatomic, readwrite, copy) NSString *pokemonEncounterId;
@property (nonatomic, readwrite, copy) NSString *ptcToken;

@end
