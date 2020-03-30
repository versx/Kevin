//
//  JobController.h
//  Jarvis++
//
//  Created by versx on 3/7/20.
//

#import "../Jarvis++/Jarvis__.h"
#import "../Settings/Settings.h"
#import "../States/DeviceState.h"
#import "../UIC/Device.h"

@interface JobController : NSObject

+(JobController *)sharedInstance;

-(void)initialize;
-(void)getAccount;
-(void)getJobs;

@end
