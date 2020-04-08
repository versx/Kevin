//
//  DeviceIPhoneNormal.m
//  Jarvis++
//
//  Created by versx on 3/31/20.
//

#import "DeviceIPhoneNormal.h"

@implementation DeviceIPhoneNormal

static DeviceCoordinateScalar *scalar;
static double _tapScalar;

-(double)tapScalar {
    return _tapScalar;
}

-(id)init:(int)width height:(int)height multiplier:(double)multiplier tapMultiplier:(double)tapMultiplier
{
    if ((self = [super init])) {
        syslog(@"[DEBUG] Device Scale: %dx%d multiplier: %f tapMultiplier: %f", width, height, multiplier, tapMultiplier);
        scalar = [[DeviceCoordinateScalar alloc] init:width
                                            heightNow:height
                                          widthTarget:375
                                         heightTarget:667
                                           multiplier:0.9//multiplier
                                        tapMultiplier:tapMultiplier
        ];
        _tapScalar = tapMultiplier;
    }
    return self;
}


#pragma mark Login Coordinates

-(DeviceCoordinate *)loginNewPlayer {
    return [[DeviceCoordinate alloc] init:320 withY:960 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginFailed {
    return [[DeviceCoordinate alloc] init:320 withY:740 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginPrivacyUpdateText {
    return [[DeviceCoordinate alloc] init:133 withY:459 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginPrivacyUpdate {
    return [[DeviceCoordinate alloc] init:375 withY:745 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)ageVerificationYear2007 {
    return [[DeviceCoordinate alloc] init:300 withY:620 andTapScalar:[self tapScalar]];
}


#pragma mark Startup Coordinates

-(DeviceCoordinate *)startup {
    return [[DeviceCoordinate alloc] init:325 withY:960 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)startupLoggedOut {
    return [[DeviceCoordinate alloc] init:400 withY:115 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)startupNewButton {
    return [[DeviceCoordinate alloc] init:475 withY:960 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)startupNewCautionSign {
    return [[DeviceCoordinate alloc] init:375 withY:385 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)closeFailedLogin {
    return [[DeviceCoordinate alloc] init:374 withY:777 andTapScalar:[self tapScalar]];
}


#pragma mark Pokemon Encounter

-(DeviceCoordinate *)encounterNoArConfirm {
    return [[DeviceCoordinate alloc] init:0 withY:0 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)encounterTmp {
    return [[DeviceCoordinate alloc] init:0 withY:0 andTapScalar:[self tapScalar]];
}


#pragma mark Items

-(DeviceCoordinate *)itemEgg {
    return [[DeviceCoordinate alloc] init:173 withY:252 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)itemEgg2 {
    return [[DeviceCoordinate alloc] init:173 withY:516 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)itemEgg3 {
    return [[DeviceCoordinate alloc] init:173 withY:785 andTapScalar:[self tapScalar]];
}


@end
