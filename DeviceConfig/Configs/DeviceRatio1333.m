//
//  DeviceRatio1333.m
//  Jarvis++
//
//  Created by versx on 3/31/20.
//

#import "DeviceRatio1333.h"

// TODO: Implement correct values

@implementation DeviceRatio1333

static DeviceCoordinateScalar *scalar;

-(id)init:(int)width height:(int)height multiplier:(double)multiplier tapMultiplier:(double)tapMultiplier
{
    if ((self = [super init])) {
        scalar = [[DeviceCoordinateScalar alloc] init:width
                                            heightNow:height
                                          widthTarget:768
                                         heightTarget:1024
                                           multiplier:multiplier
                                        tapMultiplier:tapMultiplier
        ];
    }
    return self;
}


#pragma mark Login Coordinates

-(DeviceCoordinate *)loginNewPlayer {
    return [[DeviceCoordinate alloc] init:768 withY:1425 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPTC {
    return [[DeviceCoordinate alloc] init:768 withY:1310 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginUsernameTextfield {
    return [[DeviceCoordinate alloc] init:768 withY:915 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPasswordTextfield {
    return [[DeviceCoordinate alloc] init:768 withY:1100 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginConfirm {
    return [[DeviceCoordinate alloc] init:768 withY:1296 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginBannedBackground {
    return [[DeviceCoordinate alloc] init:189 withY:1551 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginBannedText {
    return [[DeviceCoordinate alloc] init:551 withY:796 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginBanned {
    return [[DeviceCoordinate alloc] init:780 withY:1030 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginBannedSwitchAccount {
    return [[DeviceCoordinate alloc] init:768 withY:1250 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginTermsText {
    return [[DeviceCoordinate alloc] init:258 withY:500 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginTerms { //320x615
    return [[DeviceCoordinate alloc] init:768 withY:1100 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginTerms2Text {
    return [[DeviceCoordinate alloc] init:382 withY:280 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginTerms2 {
    return [[DeviceCoordinate alloc] init:768 withY:1050 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginFailedText {
    return [[DeviceCoordinate alloc] init:340 withY:732 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginFailed {
    return [[DeviceCoordinate alloc] init:768 withY:1200 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyText {
    return [[DeviceCoordinate alloc] init:768 withY:1280 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacy {
    return [[DeviceCoordinate alloc] init:768 withY:1280 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyUpdateText {
    return [[DeviceCoordinate alloc] init:270 withY:596 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)loginPrivacyUpdate {
    return [[DeviceCoordinate alloc] init:770 withY:1190 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)unableAuthText { // TODO:
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)unableAuthButton { // TODO:
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}


#pragma mark Startup Coordinates

-(DeviceCoordinate *)startup {
    return [[DeviceCoordinate alloc] init:728 withY:1542 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupLoggedOut {
    return [[DeviceCoordinate alloc] init:807 withY:177 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupOldCornerTest {
    return [[DeviceCoordinate alloc] init:1471 withY:1368 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupOldOkButton {
    return [[DeviceCoordinate alloc] init:772 withY:1159 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupNewButton {
    return [[DeviceCoordinate alloc] init:950 withY:1625 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)startupNewCautionSign {
    return [[DeviceCoordinate alloc] init:770 withY:480 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerification {
    return [[DeviceCoordinate alloc] init:775 withY:1520 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerificationYear {
    return [[DeviceCoordinate alloc] init:1040 withY:1230 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerificationYear2007 { // TODO:
    return [[DeviceCoordinate alloc] init:475 withY:1040 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerificationDragStart {
    return [[DeviceCoordinate alloc] init:1030 withY:1780 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)ageVerificationDragEnd {
    return [[DeviceCoordinate alloc] init:1030 withY:0 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)passenger {
    return [[DeviceCoordinate alloc] init:768 withY:1567 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)weather {
    return [[DeviceCoordinate alloc] init:768 withY:1360 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeWeather1 {
    return [[DeviceCoordinate alloc] init:1300 withY:1700 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeWeather2 {
    return [[DeviceCoordinate alloc] init:768 withY:2000 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeWarning {
    return [[DeviceCoordinate alloc] init:768 withY:1800 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeNews {
    return [[DeviceCoordinate alloc] init:768 withY:1700 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)compareWarningL {
    return [[DeviceCoordinate alloc] init:90 withY:1800 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)compareWarningR {
    return [[DeviceCoordinate alloc] init:550 withY:1800 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)closeFailedLogin {
    return [[DeviceCoordinate alloc] init:765 withY:1250 andDeviceCoordinateScalar:scalar];
}


#pragma mark Menu Coordinates

-(DeviceCoordinate *)closeMenu {
    return [[DeviceCoordinate alloc] init:770 withY:1874 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)mainScreenPokeballRed {
    return [[DeviceCoordinate alloc] init:768 withY:1790 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)settingsPageCloseButton {
    return [[DeviceCoordinate alloc] init:768 withY:1850 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)trackerMenu { // TODO:
    return [[DeviceCoordinate alloc] init:1200 withY:1040 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)trackerTopCenter { // TODO:
    return [[DeviceCoordinate alloc] init:768 withY:286 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)trackerBottomCenter { // TODO:
    return [[DeviceCoordinate alloc] init:768 withY:2200 andDeviceCoordinateScalar:scalar];
}


#pragma mark Tutorial

-(DeviceCoordinate *)compareTutorialL {
    return [[DeviceCoordinate alloc] init:375 withY:1650 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)compareTutorialR {
    return [[DeviceCoordinate alloc] init:1150 withY:1650 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialNext {
    return [[DeviceCoordinate alloc] init:1400 withY:1949 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialGenderFemale { // TODO:
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialStyleConfirm {
    return [[DeviceCoordinate alloc] init:768 withY:1024 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialCatchConfirm {
    return [[DeviceCoordinate alloc] init:768 withY:1600 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialPokestopConfirm { // TODO:
    return [[DeviceCoordinate alloc] init:327 withY:765 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)checkArPeristence { // TODO:
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialPokemonAtFeet { // TODO:
    return [[DeviceCoordinate alloc] init:324 withY:818 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)tutorialWillowPrompt { // TODO:
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}


#pragma mark Pokemon Encounter

-(DeviceCoordinate *)encounterNoAr { // TODO:
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)encounterNoArConfirm { // TODO:
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)encounterTmp { // TODO:
    return [[DeviceCoordinate alloc] init:0 withY:0 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)encounterPokemonRun {
    return [[DeviceCoordinate alloc] init:100 withY:170 andDeviceCoordinateScalar:scalar];
}


#pragma mark Items

-(DeviceCoordinate *)openItems {
    return [[DeviceCoordinate alloc] init:1165 withY:1620 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEggMenuItem {
    return [[DeviceCoordinate alloc] init:325 withY:325 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEggDeploy {
    return [[DeviceCoordinate alloc] init:768 withY:1500 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEgg {
    return [[DeviceCoordinate alloc] init:325 withY:483 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEgg2 {
    return [[DeviceCoordinate alloc] init:325 withY:950 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)itemEgg3 {
    return [[DeviceCoordinate alloc] init:325 withY:1900 andDeviceCoordinateScalar:scalar];
}


#pragma mark Account

-(DeviceCoordinate *)loginPermanentBan {
    return [[DeviceCoordinate alloc] init:308 withY:329 andDeviceCoordinateScalar:scalar];
}


#pragma mark Adventure Sync

-(DeviceCoordinate *)adventureSyncRewards {
    return [[DeviceCoordinate alloc] init:768 withY:500 andDeviceCoordinateScalar:scalar];
}
-(DeviceCoordinate *)adventureSyncButton {
    return [[DeviceCoordinate alloc] init:768 withY:1740 andDeviceCoordinateScalar:scalar];
}


@end
