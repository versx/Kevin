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

+(instancetype)sharedInstance;

/**
* Send an `init` request to backend and initialize
*/
-(void)initialize;

/**
* Send a `get_account` request to backend and grab an account
*/
-(void)getAccount;

/**
* Start sending `get_job` requests to backend to grab jobs
*/
-(void)getJobs;

@end
