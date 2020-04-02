//
//  DeviceCoordinate.m
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import "DeviceCoordinate.h"

@implementation DeviceCoordinate

@synthesize x;
@synthesize y;
@synthesize tapX;
@synthesize tapY;

-(NSString *)description {
    return [NSString stringWithFormat:@"[x=%d y=%d tapX=%d tapY=%d]", x, y, tapX, tapY];
}

-(id)init:(int)x withY:(int)y andTapScalar:(double)scalar
{
    self = [super init];
    if (self) {
        self.x = x;
        self.y = y;
        self.tapX = (int)lround(x * scalar);
        self.tapY = (int)lround(y * scalar);
    }
    return self;
}

-(id)init:(int)x withY:(int)y andDeviceCoordinateScalar:(DeviceCoordinateScalar *)scalar
{
    self = [super init];
    if (self) {
        self.x = [scalar scaleX:x];
        self.y = [scalar scaleY:y];
        self.tapX = [scalar tapScaleX:x];
        self.tapY = [scalar tapScaleY:y];
    }
    return self;
}

/*
-(XCUICoordinate *)toXCUICoordinate:(XCUIApplication *)app
{
    return [app coordinateWithNormalizedOffset:CGVectorMake([self tapX], [self tapY])];
}
*/

@end
