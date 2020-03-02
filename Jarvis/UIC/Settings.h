//
//  Settings.h
//  Jarvis++
//
//  Created by versx on 3/1/20.
//

@interface Settings : NSObject

+(instancetype)sharedInstance;

// TODO: Individual settings
-(NSDictionary *)config;
-(BOOL)enableAccountManager;

@end
