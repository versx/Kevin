//
//  DeviceConfig.m
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import "DeviceConfig.h"

// TODO: Support multiple device configs

@implementation DeviceConfig

static DeviceCoordinateScalar *scalar;

+(DeviceConfig *)sharedInstance
{
    static DeviceConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DeviceConfig alloc] init];
    });
    return sharedInstance;
}

-(id)init
{
    
    self = [super init];
    if (self) {
        scalar = [[DeviceCoordinateScalar alloc] init];
        scalar.widthNow = [UIScreen mainScreen].bounds.size.width;
        scalar.heightNow = [UIScreen mainScreen].bounds.size.height;
        scalar.widthTarget = 320;
        scalar.heightTarget = 568;
        scalar.multiplier = 1.0; // 5S/SE
        scalar.tapMultiplier = 0.5; // iOS 13 = 0.5
    }
    return self;
}


#pragma mark Login Coordinates

-(DeviceCoordinate *)loginNewPlayer {
    return [[DeviceCoordinate alloc] init:320 withY:785 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPTC {
    return [[DeviceCoordinate alloc] init:320 withY:800 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginUsernameTextfield {
    return [[DeviceCoordinate alloc] init:320 withY:500 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPasswordTextfield {
    return [[DeviceCoordinate alloc] init:320 withY:600 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginConfirm {
    return [[DeviceCoordinate alloc] init:375 withY:680 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginBannedBackground {
    return [[DeviceCoordinate alloc] init:100 withY:900 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginBannedText {
    return [[DeviceCoordinate alloc] init:230 withY:473 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginBanned {
    return [[DeviceCoordinate alloc] init:320 withY:585 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginBannedSwitchAccount {
    return [[DeviceCoordinate alloc] init:320 withY:660 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginTermsText {
    return [[DeviceCoordinate alloc] init:109 withY:351 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginTerms {
    return [[DeviceCoordinate alloc] init:320 withY:615 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginTerms2Text {
    return [[DeviceCoordinate alloc] init:109 withY:374 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginTerms2 {
    return [[DeviceCoordinate alloc] init:320 withY:620 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginFailedText {
    return [[DeviceCoordinate alloc] init:297 withY:526 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginFailed {
    return [[DeviceCoordinate alloc] init:320 withY:670 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyText {
    return [[DeviceCoordinate alloc] init:328 withY:748 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacy {
    return [[DeviceCoordinate alloc] init:320 withY:625 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyUpdateText {
    return [[DeviceCoordinate alloc] init:110 withY:389 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyUpdate {
    return [[DeviceCoordinate alloc] init:320 withY:625 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)unableAuthText {
    return [[DeviceCoordinate alloc] init:330 withY:530 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)unableAuthButton {
    return [[DeviceCoordinate alloc] init:320 withY:585 andDeviceCoordinateScalar:scalar];
}


#pragma mark Startup Coordinates

-(DeviceCoordinate *)startup {
    return [[DeviceCoordinate alloc] init:280 withY:800 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupLoggedOut {
    return [[DeviceCoordinate alloc] init:320 withY:175 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupNewButton {
    return [[DeviceCoordinate alloc] init:400 withY:820 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupNewCautionSign {
    return [[DeviceCoordinate alloc] init:320 withY:320 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerification {
    return [[DeviceCoordinate alloc] init:222 withY:815 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerificationYear {
    return [[DeviceCoordinate alloc] init:475 withY:690 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerificationYear2007 {
    return [[DeviceCoordinate alloc] init:475 withY:1040 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)passenger {
    return [[DeviceCoordinate alloc] init:320 withY:775 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)weather {
    return [[DeviceCoordinate alloc] init:320 withY:780 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeWeather1 {
    return [[DeviceCoordinate alloc] init:240 withY:975 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeWeather2 {
    return [[DeviceCoordinate alloc] init:220 withY:1080 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeWarning {
    return [[DeviceCoordinate alloc] init:320 withY:960 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeNews {
    return [[DeviceCoordinate alloc] init:320 withY:960 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)compareWarningL {
    return [[DeviceCoordinate alloc] init:90 withY:950 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)compareWarningR {
    return [[DeviceCoordinate alloc] init:550 withY:950 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeFailedLogin {
    return [[DeviceCoordinate alloc] init:315 withY:665 andDeviceCoordinateScalar:scalar];
}


#pragma mark Menu Coordinates

-(DeviceCoordinate *)closeMenu {
    return [[DeviceCoordinate alloc] init:320 withY:1060 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)mainScreenPokeballRed {
    return [[DeviceCoordinate alloc] init:320 withY:1020 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)settingsPageCloseButton {
    return [[DeviceCoordinate alloc] init:320 withY:1020 andDeviceCoordinateScalar:scalar];
}

@end
