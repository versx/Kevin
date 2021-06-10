//
//  DeviceCoordinate.h
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import "DeviceCoordinateScalar.h"

#import <XCTest/XCTest.h>

@interface DeviceCoordinate : NSObject

@property int x;
@property int y;
@property int tapX;
@property int tapY;

-(id)init:(int)x withY:(int)y andTapScalar:(double)scalar;
-(id)init:(int)x withY:(int)y andDeviceCoordinateScalar:(DeviceCoordinateScalar *)scalar;

//-(XCUICoordinate *)toXCUICoordinate:(XCUIApplication *)app;

@end
