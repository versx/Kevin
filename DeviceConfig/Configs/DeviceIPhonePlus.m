//
//  DeviceIPhonePlus.m
//  Jarvis++
//
//  Created by versx on 3/31/20.
//

#import "DeviceIPhonePlus.h"

@implementation DeviceIPhonePlus : DeviceRatio1775

#pragma mark Login Coordinates

-(DeviceCoordinate *)loginNewPlayer {
    return [[DeviceCoordinate alloc] init:600 withY:1500 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginPTC {
    return [[DeviceCoordinate alloc] init:600 withY:1400 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginUsernameTextfield {
    return [[DeviceCoordinate alloc] init:600 withY:950 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginPasswordTextfield {
    return [[DeviceCoordinate alloc] init:600 withY:1150 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginConfirm {
    return [[DeviceCoordinate alloc] init:600 withY:1350 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginBannedText {
    return [[DeviceCoordinate alloc] init:450 withY:920 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginBanned {
    return [[DeviceCoordinate alloc] init:620 withY:1130 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)loginBannedSwitchAccount {
    return [[DeviceCoordinate alloc] init:620 withY:1287 andTapScalar:[self tapScalar]];
}


#pragma mark Startup Coordinates

-(DeviceCoordinate *)startupOldCornerTest {
    return [[DeviceCoordinate alloc] init:1180 withY:1400 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)startupOldOkButton {
    return [[DeviceCoordinate alloc] init:625 withY:1210 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)startupNewButton {
    return [[DeviceCoordinate alloc] init:790 withY:1560 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)startupNewCautionSign {
    return [[DeviceCoordinate alloc] init:620 withY:620 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)ageVerificationDragStart {
    return [[DeviceCoordinate alloc] init:900 withY:1980 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)ageVerificationYear {
    return [[DeviceCoordinate alloc] init:900 withY:1300 andTapScalar:[self tapScalar]];
}
-(DeviceCoordinate *)ageVerificationYear2007 {
    return [[DeviceCoordinate alloc] init:900 withY:2050 andTapScalar:[self tapScalar]];
}


@end
