//
//  DeviceIPhoneNormal.m
//  Jarvis++
//
//  Created by versx on 3/31/20.
//

#import "DeviceIPhoneNormal.h"

// TODO: Implement correct values

@implementation DeviceIPhoneNormal

static DeviceCoordinateScalar *scalar;

-(id)init:(int)width height:(int)height multiplier:(double)multiplier tapMultiplier:(double)tapMultiplier
{
    if ((self = [super init])) {
        scalar = [[DeviceCoordinateScalar alloc] init:width
                                            heightNow:height
                                          widthTarget:750
                                         heightTarget:1334
                                           multiplier:multiplier
                                        tapMultiplier:tapMultiplier
        ];
    }
    return self;
}


#pragma mark Login Coordinates

-(DeviceCoordinate *)loginNewPlayer {
    return [[DeviceCoordinate alloc] init:320 withY:925 andDeviceCoordinateScalar:scalar];
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
-(DeviceCoordinate *)loginTerms { //320x615
    return [[DeviceCoordinate alloc] init:320 withY:600 andDeviceCoordinateScalar:scalar];
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
    return [[DeviceCoordinate alloc] init:320 withY:740 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyText {
    return [[DeviceCoordinate alloc] init:328 withY:748 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacy {
    return [[DeviceCoordinate alloc] init:320 withY:625 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyUpdateText {
    return [[DeviceCoordinate alloc] init:133 withY:459 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyUpdate {
    return [[DeviceCoordinate alloc] init:375 withY:745 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)unableAuthText {
    return [[DeviceCoordinate alloc] init:330 withY:530 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)unableAuthButton {
    return [[DeviceCoordinate alloc] init:320 withY:585 andDeviceCoordinateScalar:scalar];
}


#pragma mark Startup Coordinates

-(DeviceCoordinate *)startup {
    return [[DeviceCoordinate alloc] init:325 withY:960 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupLoggedOut {
    return [[DeviceCoordinate alloc] init:400 withY:115 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupOldCornerTest {
    return [[DeviceCoordinate alloc] init:610 withY:715 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupOldOkButton {
    return [[DeviceCoordinate alloc] init:320 withY:650 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupNewButton {
    return [[DeviceCoordinate alloc] init:475 withY:960 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupNewCautionSign {
    return [[DeviceCoordinate alloc] init:375 withY:385 andDeviceCoordinateScalar:scalar];
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
-(DeviceCoordinate *)ageVerificationDragStart {
    return [[DeviceCoordinate alloc] init:475 withY:1025 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerificationDragEnd {
    return [[DeviceCoordinate alloc] init:475 withY:380 andDeviceCoordinateScalar:scalar];
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
    return [[DeviceCoordinate alloc] init:374 withY:777 andDeviceCoordinateScalar:scalar];
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
-(DeviceCoordinate *)trackerMenu {
    return [[DeviceCoordinate alloc] init:600 withY:1040 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)trackerTopCenter {
    return [[DeviceCoordinate alloc] init:320 withY:143 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)trackerBottomCenter {
    return [[DeviceCoordinate alloc] init:320 withY:1110 andDeviceCoordinateScalar:scalar];
}


#pragma mark Tutorial

-(DeviceCoordinate *)compareTutorialL {
    return [[DeviceCoordinate alloc] init:100 withY:900 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)compareTutorialR {
    return [[DeviceCoordinate alloc] init:550 withY:900 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialNext {
    return [[DeviceCoordinate alloc] init:565 withY:1085 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialGenderFemale {
    return [[DeviceCoordinate alloc] init:503 withY:518 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialStyleConfirm {
    return [[DeviceCoordinate alloc] init:321 withY:588 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialCatchConfirm {
    return [[DeviceCoordinate alloc] init:310 withY:755 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialPokestopConfirm {
    return [[DeviceCoordinate alloc] init:327 withY:765 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)checkArPeristence {
    return [[DeviceCoordinate alloc] init:557 withY:101 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialPokemonAtFeet {
    return [[DeviceCoordinate alloc] init:324 withY:818 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialWillowPrompt {
    return [[DeviceCoordinate alloc] init:320 withY:320 andDeviceCoordinateScalar:scalar];
}


#pragma mark Pokemon Encounter

-(DeviceCoordinate *)encounterNoAr {
    return [[DeviceCoordinate alloc] init:312 withY:1070 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)encounterNoArConfirm {
    return [[DeviceCoordinate alloc] init:320 withY:645 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)encounterTmp {
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)encounterPokemonRun {
    return [[DeviceCoordinate alloc] init:50 withY:75 andDeviceCoordinateScalar:scalar];
}


#pragma mark Items

-(DeviceCoordinate *)openItems {
    return [[DeviceCoordinate alloc] init:500 withY:950 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEggMenuItem {
    return [[DeviceCoordinate alloc] init:325 withY:225 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEggDeploy {
    return [[DeviceCoordinate alloc] init:315 withY:880 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEgg {
    return [[DeviceCoordinate alloc] init:173 withY:215 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEgg2 {
    return [[DeviceCoordinate alloc] init:173 withY:450 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEgg3 {
    return [[DeviceCoordinate alloc] init:173 withY:950 andDeviceCoordinateScalar:scalar];
}


#pragma mark Account

-(DeviceCoordinate *)loginPermanentBan {
    return [[DeviceCoordinate alloc] init:308 withY:329 andDeviceCoordinateScalar:scalar];
}


#pragma mark Adventure Sync

-(DeviceCoordinate *)adventureSyncRewards {
    return [[DeviceCoordinate alloc] init:320 withY:300 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)adventureSyncButton {
    return [[DeviceCoordinate alloc] init:320 withY:978 andDeviceCoordinateScalar:scalar];
}


@end
