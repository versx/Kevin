//
//  DeviceConfig.h
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import "../DeviceCoordinate/DeviceCoordinate.h"

@interface DeviceConfig : NSObject

+(DeviceConfig *)sharedInstance;

// Login

-(DeviceCoordinate *)loginNewPlayer;
-(DeviceCoordinate *)loginPTC;
-(DeviceCoordinate *)loginUsernameTextfield;
-(DeviceCoordinate *)loginPasswordTextfield;
-(DeviceCoordinate *)loginConfirm;
-(DeviceCoordinate *)loginBannedBackground;
-(DeviceCoordinate *)loginBanned;
-(DeviceCoordinate *)loginBannedSwitchAccount;
-(DeviceCoordinate *)loginTermsText;
-(DeviceCoordinate *)loginTerms;
-(DeviceCoordinate *)loginTerms2Text;
-(DeviceCoordinate *)loginTerms2;
-(DeviceCoordinate *)loginFailedText;
-(DeviceCoordinate *)loginFailed;
-(DeviceCoordinate *)loginPrivacyText;
-(DeviceCoordinate *)loginPrivacy;
-(DeviceCoordinate *)loginPrivacyUpdateText;
-(DeviceCoordinate *)loginPrivacyUpdate;
-(DeviceCoordinate *)unableAuthText;
-(DeviceCoordinate *)unableAuthButton;

// Startup
-(DeviceCoordinate *)startup;
-(DeviceCoordinate *)startupLoggedOut;
-(DeviceCoordinate *)startupNewButton;
-(DeviceCoordinate *)startupNewCautionSign;
-(DeviceCoordinate *)ageVerification;
-(DeviceCoordinate *)ageVerificationYear;
-(DeviceCoordinate *)ageVerificationYear2007;
-(DeviceCoordinate *)passenger;
-(DeviceCoordinate *)weather;
-(DeviceCoordinate *)closeWeather1;
-(DeviceCoordinate *)closeWeather2;
-(DeviceCoordinate *)closeWarning;
-(DeviceCoordinate *)closeNews;
-(DeviceCoordinate *)compareWarningL;
-(DeviceCoordinate *)compareWarningR;
-(DeviceCoordinate *)closeFailedLogin;

// Menu
-(DeviceCoordinate *)closeMenu;
-(DeviceCoordinate *)mainScreenPokeballRed;
-(DeviceCoordinate *)settingsPageCloseButton;


@end
