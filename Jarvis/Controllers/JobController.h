//
//  JobController.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import <Foundation/Foundation.h>

#import "../States/DeviceState.h"
#import "../UIC/Device.h"
#import "../UIC/Settings.h"
#import "../Utilities/Utils.h"

@interface JobController : NSObject

-(void)handlePokemonJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning;
-(void)handleRaidJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning;
-(void)handleQuestJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning;
-(void)handleLeveling:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning;
-(void)handleIVJob:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning;
-(void)handleSwitchAccount:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning;
-(void)handleGatherToken:(NSString *)action withData:(NSDictionary *)data hasWarning:(BOOL)hasWarning;

@end
