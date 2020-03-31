//
//  JobController.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "../Settings/Settings.h"
#import "../States/DeviceState.h"
#import "../UIC/Device.h"
#import "../UIC/UIC.h"

@interface JobController : NSObject

+(JobController *)sharedInstance;

-(void)initialize;
-(void)getAccount;
-(void)getJobs;

@end
