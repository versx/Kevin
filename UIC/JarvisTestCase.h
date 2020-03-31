//
//  JarvisTestCase.h
//  Jarvis++
//
//  Created by versx on 3/14/20.
//

#import <CoreLocation/CoreLocation.h>
#import <KIF/KIFUIViewTestActor.h>
#import <KIF/XCTestCase-KIFAdditions.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIKit.h>

#import "../DeviceConfig/DeviceConfig.h"
#import "../DeviceCoordinate/DeviceCoordinate.h"

@interface JarvisTestCase : KIFTestCase

+(JarvisTestCase *)sharedInstance;

-(void)registerUIInterruptionHandler:(NSString *)description;

+(void)type:(NSString *)text;
+(void)touch:(int)x withY:(int)y;
+(void)drag:(DeviceCoordinate *)start toPoint:(DeviceCoordinate *)end;
+(void)swipe;

@end
