//
//  DeviceConfigProtocol.h
//  Jarvis++
//
//  Created by versx on 3/31/20.
//

#import "../DeviceCoordinate/DeviceCoordinate.h"

@protocol DeviceConfigProtocol <NSObject>

-(id)init:(int)width height:(int)height multiplier:(double)multiplier tapMultiplier:(double)tapMultiplier;


#pragma mark Login Coordinates

/** New player button. */
-(DeviceCoordinate *)loginNewPlayer;
/** Login with PTC button. */
-(DeviceCoordinate *)loginPTC;
/** Login username text field. */
-(DeviceCoordinate *)loginUsernameTextfield;
/** Login password text field. */
-(DeviceCoordinate *)loginPasswordTextfield;
/** Login button. */
-(DeviceCoordinate *)loginConfirm;
/** ? pixel in background of suspension notice. */ //TODO: - Where?
-(DeviceCoordinate *)loginBannedBackground;
/** Green pixel in "TRY A DIFFERENT ACCOUNT" button of "Failed to login" popup. */
-(DeviceCoordinate *)loginBannedText;
/** Green pixel in "Retry" button of "Failed to login" popup. */
-(DeviceCoordinate *)loginBanned;
/** "Switch Accounts" button of "Failed to login" popup. */
-(DeviceCoordinate *)loginBannedSwitchAccount;
/** Black pixel in terms (new account) popup thats white in all other login popups. */
-(DeviceCoordinate *)loginTermsText;
/** Green pixel in button of terms (new account) popup. */
-(DeviceCoordinate *)loginTerms;
/** Black pixel in terms (old account) popup thats white in all other login popups. */
-(DeviceCoordinate *)loginTerms2Text;
/** Green pixel in button of terms (old account) popup. */
-(DeviceCoordinate *)loginTerms2;
/** Black pixel in "Invalid Credentials" popup thats white in all other login popups. */
-(DeviceCoordinate *)loginFailedText;
/** Green pixel in button of "Invalid Credential" popup. */
-(DeviceCoordinate *)loginFailed;
/** Green pixel in button of privacy popup (Privacy button). */
-(DeviceCoordinate *)loginPrivacyText;
/** Green pixel in button of privacy popup (OK button). */
-(DeviceCoordinate *)loginPrivacy;
/** Black pixel in text of privacy update popup. */
-(DeviceCoordinate *)loginPrivacyUpdateText;
/** Green pixel in button of privacy update popup (OK button). */
-(DeviceCoordinate *)loginPrivacyUpdate;
/** Black pixel in bottom row of text in the unable to authenticate popup. */
-(DeviceCoordinate *)unableAuthText;
/** Green pixel in the OK button. */
-(DeviceCoordinate *)unableAuthButton;


#pragma mark Startup Coordinates

/** Green pixel in green button of startup popup. */
-(DeviceCoordinate *)startup;
/** Green pixel in green button of log in button if not logged in. */
-(DeviceCoordinate *)startupLoggedOut;
/** White Pixel (on 3 line prompt) or Greenish-Blue Pixel (on 2 line prompt) bottom right corner of 2line popup. **/
-(DeviceCoordinate *)startupOldCornerTest;
/** Light Green Pixel, Inside the OK button, centered between OK, kept same pixels despite height change. **/
-(DeviceCoordinate *)startupOldOkButton;
/** Light Green Pixel, Centered inside OK button again, just lower. **/
-(DeviceCoordinate *)startupNewButton;
/** Yellow pixel, in upper section of traingle, below the black outline border. **/
-(DeviceCoordinate *)startupNewCautionSign;
/** Green pixel in green button of submit if not age verified. */
-(DeviceCoordinate *)ageVerification;
/** Location of Year box on birthday prompt for fresh installs. **/
-(DeviceCoordinate *)ageVerificationYear;
/** Location of Year '2007' on birthday prompt scroll view. **/
-(DeviceCoordinate *)ageVerificationYear2007;
/** Location to start Scrolling for Birth year. **/
-(DeviceCoordinate *)ageVerificationDragStart;
/** Location to end Scrolling for Birth year. **/
-(DeviceCoordinate *)ageVerificationDragEnd;
/** ? pixel in ? of logged out. */ //TODO: - Where?
-(DeviceCoordinate *)passenger;
/** ? pixel in ? of weather popup. */ //TODO: - Where?
-(DeviceCoordinate *)weather;
/** Button to close weather popup Step 1. */
-(DeviceCoordinate *)closeWeather1;
/** Button to close weather popup Step 2. */
-(DeviceCoordinate *)closeWeather2;
/** Button to close warning (First Strike). */
-(DeviceCoordinate *)closeWarning;
/** Empty place to close news. */
-(DeviceCoordinate *)closeNews;
/** Black pixel in warning (First Strike) popup on the left side. */
-(DeviceCoordinate *)compareWarningL;
/** Black pixel in warning (First Strike) popup on the right side. */
-(DeviceCoordinate *)compareWarningR;
/** Trying to Fix The persisting Login Issue. **/
-(DeviceCoordinate *)closeFailedLogin;


#pragma mark Menu Coordinates

/** Button to option nenu. Also white pixel in Pokeball on main screen. */
-(DeviceCoordinate *)closeMenu;
/** Red pixel in Pokeball on main screen. */
-(DeviceCoordinate *)mainScreenPokeballRed;
/** White pixel in close button on setting page(when pokeball first tapped). */
-(DeviceCoordinate *)settingsPageCloseButton;
/** Nearby Pokemon tracker. */
-(DeviceCoordinate *)trackerMenu;
/** Top center white pixel above 'Nearby' title. */
-(DeviceCoordinate *)trackerTopCenter;
/** Bottom center white pixel below close button. */
-(DeviceCoordinate *)trackerBottomCenter;


#pragma mark Tutorial Coordinates

/** Dark pixel in warning initial Tutorial screen on the left side. */
-(DeviceCoordinate *)compareTutorialL;
/** Dark pixel in warning initial Tutorial screen on the right side. */
-(DeviceCoordinate *)compareTutorialR;
/** Next button in bottom right. */
-(DeviceCoordinate *)tutorialNext;
/** Female red shirt. */
-(DeviceCoordinate *)tutorialGenderFemale;
/** Are you done? -> Yes. */
-(DeviceCoordinate *)tutorialStyleConfirm;
/** Middle of OK button for confirm catch screen. */
-(DeviceCoordinate *)tutorialCatchConfirm;
/**  */
-(DeviceCoordinate *)tutorialPokestopConfirm;
/** Check White pixel in AR button above scroll bar of toggle. */
-(DeviceCoordinate *)checkArPeristence;
/** Check if Pokemon spawn on top of trainers feet. */
-(DeviceCoordinate *)tutorialPokemonAtFeet;
/** Willow Prompt. */
-(DeviceCoordinate *)tutorialWillowPrompt;


#pragma mark Pokemon Encounter Coordinates

/** Green pixel in green button of no AR(+) button. */
-(DeviceCoordinate *)encounterNoAr;
/** Green button of no AR(+) confirm button. */
-(DeviceCoordinate *)encounterNoArConfirm;
/** Temp! Exit AR-Mode. */
-(DeviceCoordinate *)encounterTmp;
/** White pixel in run from Pokemon button. */
-(DeviceCoordinate *)encounterPokemonRun;
/** Red pixel in switch Pokeball button. */
-(DeviceCoordinate *)encounterPokeball;


#pragma mark Item Coordinates

/** Open items button in menu. */
-(DeviceCoordinate *)openItems;
/** Luck Egg menu item: Will always be first after deletion unless active. */
-(DeviceCoordinate *)itemEggMenuItem;
/** Tap location for Egg deployment. */
-(DeviceCoordinate *)itemEggDeploy;
/** Blue pixel in egg at 1st slot. */
-(DeviceCoordinate *)itemEgg;
/** Blue pixel in egg at 2nd slot. */
-(DeviceCoordinate *)itemEgg2;
/** Blue pixel in egg at 3rd slot. */
-(DeviceCoordinate *)itemEgg3;

#pragma mark Accounts Coordinates

/** White pixel in the last `n` of termination. TODO: Fix, find white pixel in permanent instead. */
-(DeviceCoordinate *)loginPermanentBan;


#pragma mark Adventure Sync Coordinates

/** Pink pixel in background of "Rewards" in adventure sync pop-up. */
-(DeviceCoordinate *)adventureSyncRewards;
/** Green/Blue pixel in claim/close button of adventure sync pop-up. */
-(DeviceCoordinate *)adventureSyncButton;


@end
