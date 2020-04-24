//
//  UIC.mm
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "UIC.h"

// TODO: Handle warning accounts (make config option to allow/not allow)
// TODO: Fetch config from DCM, if no config provided wait until one is.
// TODO: Fix crash after 10 minutes during leveling issue
// TODO: Fix 6/6+/6s/7/7+/iPad support
// TODO: Handle invalid usernames
// TODO: Handle 'What was your name again?' screens
// TODO: Make tutorial parts reusable
// TODO: Pixel offsets in remote config
// TODO: Fix https://developer.apple.com/documentation/xctest/xctestcase/1496273-adduiinterruptionmonitorwithdesc
// TODO: Use https://github.com/mattstevens/RoutingHTTPServer for routes
// TODO: Toggle WiFi https://stackoverflow.com/questions/14653058/disable-wifi-on-iphone-using-objective-c
// REFERENCE: Find pixel location from screenshot - http://nicodjimenez.github.io/boxLabel/annotate.html

@implementation UIC2

#pragma mark Variables

static HTTPServer *_httpServer;
static dispatch_queue_t _heartbeatQueue;
static dispatch_queue_t _pixelCheckQueue;
static BOOL _dataStarted = false;
//static NSLock *_lock = [[NSLock alloc] init];


#pragma mark Constructor/Deconstructor

-(id)init
{
    if ((self = [super init])) {
        _heartbeatQueue = dispatch_queue_create("heartbeat_queue", NULL);
        _pixelCheckQueue = dispatch_queue_create("pixelcheck_queue", NULL);
    }
    
    return self;
}

-(void)dealloc
{
    [_httpServer release];
    [_heartbeatQueue release];
    [_pixelCheckQueue release];
    [super dealloc];
}


#pragma mark Login Handlers

-(void)start
{
    /*
    int imageCount = _dyld_image_count();
    for (int i = 0; i < imageCount; i++) {
        if (strcmp(_dyld_get_image_name(i), "") == 0) {
        }
        NSLog(@"[Jarvis] [DYLD] %d - %s", i, _dyld_get_image_name(i));
    }
    */

    //dispatch_async(dispatch_queue_create("wait_queue", NULL), ^{
        while (![[Settings sharedInstance] gotConfig]) {
            sleep(1);
        }

        syslog(@"[INFO] %@ (%@) running %@ %@ with a delay of %@ and a tap multiplier of %f",
               [[Device sharedInstance] uuid], [[Device sharedInstance] model],
               [[Device sharedInstance] osName], [[Device sharedInstance] osVersion],
               [[Device sharedInstance] delayMultiplier],
               [DeviceConfig tapMultiplier]);
        
        syslog(@"[INFO] CPU Usage: %@%%, Count: %lu, Uptime: %@, Thermal State: %@",
               [[SystemInfo sharedInstance] cpuUsage],
               (unsigned long)[[SystemInfo sharedInstance] processorCount],
               [SystemInfo formatTimeInterval:[[SystemInfo sharedInstance] systemUptime]],
               [SystemInfo formatThermalState:[[SystemInfo sharedInstance] thermalState]]);
        
        syslog(@"[INFO] RAM: %@, Used: %@, Free: %@",
               [SystemInfo formatBytes:[[[SystemInfo sharedInstance] totalMemory] longValue]],
               [SystemInfo formatBytes:[[[SystemInfo sharedInstance] usedMemory] longValue]],
               [SystemInfo formatBytes:[[[SystemInfo sharedInstance] freeMemory] longValue]]);
        
        syslog(@"[INFO] HDD: %@, Used: %@, Free: %@",
               [SystemInfo formatBytes:[[[SystemInfo sharedInstance] totalSpace] longValue]],
               [SystemInfo formatBytes:[[[SystemInfo sharedInstance] usedSpace] longValue]],
               [SystemInfo formatBytes:[[[SystemInfo sharedInstance] freeSpace] longValue]]);

        // Check that the device is supported
        if ([DeviceConfig sharedInstance] == nil) {
            return;
        }
        syslog(@"[DEBUG] DeviceConfig: %@", [DeviceConfig sharedInstance]);

        //JarvisTestCase *jarvis = [[JarvisTestCase alloc] init];
        //[jarvis runTest];
        //[jarvis registerUIInterruptionHandler:@"System Dialog"];

        // Initalize our http server
        _httpServer = [[HTTPServer alloc] init];
        [_httpServer setPort:[[Settings sharedInstance] port]];
        [_httpServer setConnectionClass:[HttpClientConnection class]];

        // TODO: Attempt to start HTTP server, if fails, reboot app or try again.
        NSError *error = nil;
        if (![_httpServer start:&error]) {
            syslog(@"[ERROR] Error starting HTTP Server: %@", error);
            return;
        }

        [self login];
    //});
}

-(void)login
{
    // Initialize the device with the backend controller.
    [[JobController sharedInstance] initialize];
    [[DeviceState sharedInstance] setIsStartup:true];
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSString *username = [[Device sharedInstance] username];
    syslog(@"[DEBUG] Checking if usernam==nil and accountManager==true: %@", username);
    if ([username isNullOrEmpty] && [[Settings sharedInstance] enableAccountManager]) {
        syslog(@"[DEBUG] Username is empty and account manager is enabled, starting account request...");
        NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
        data[@"uuid"] = [[Device sharedInstance] uuid];
        data[@"username"] = [[Device sharedInstance] username];
        data[@"min_level"] = [[Device sharedInstance] minLevel];
        data[@"max_level"] = [[Device sharedInstance] maxLevel];
        data[@"type"] = TYPE_GET_ACCOUNT;
        //syslog(@"[DEBUG] Sending get_account request: %@", data);
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:data
                  blocking:true
                completion:^(NSDictionary *result) {
            syslog(@"[DEBUG] get_account sent, response %@", result);
            if ([[result objectForKey:@"status"] isEqualToString:@"error"]) {
                syslog(@"[ERROR] Failed to get account from backend: %@", result[@"error"]);
                return;
            }
            NSDictionary *data = [result objectForKey:@"data"];
            NSString *user = data[@"username"];
            NSString *pass = data[@"password"];
            if (data == nil || user == nil || pass == nil) {
                syslog(@"[ERROR] Failed to get account and not logged in.");
                //shouldExit = true;
                return;
            }
            [[Device sharedInstance] setUsername:user];
            [[Device sharedInstance] setPassword:pass];
            //[[Device sharedInstance] setNewLogIn:true];
            [[Device sharedInstance] setIsLoggedIn:false];
            
            [DeviceState checkWarning:data[@"first_warning_timestamp"]];
            syslog(@"[INFO] Got account %@ from backend.", user);
            dispatch_semaphore_signal(sem);
        }];
    } else {
        syslog(@"[DEBUG] Already have an account.");
        dispatch_semaphore_signal(sem);
    }
    
    // Wait until we get a response from the backend for `get_account` request.
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
    // Delay execution of my block for 5/30 seconds depending on device model.
    NSNumber *delay = [[Device sharedInstance] is1GbDevice] ? @15 /*5S*/ : @5; /*SE*/
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, [delay intValue] * NSEC_PER_SEC);
    dispatch_after(time, dispatch_get_main_queue(), ^{
        [self startHeartbeatLoop]; // TODO: Start heartbeat first time after receiving data.
        // Start login sequence and detection after we connect to backend.
        dispatch_async(_pixelCheckQueue, ^{
            sleep(5);
            [self startPixelCheckLoop];
        });
    });
}

-(void)startHeartbeatLoop
{
    syslog(@"[DEBUG] Starting heartbeat dispatch queue...");
    bool heartbeatRunning = true;
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    data[@"uuid"] = [[Device sharedInstance] uuid];
    data[@"username"] = [[Device sharedInstance] username];
    data[@"type"] = TYPE_HEARTBEAT;
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:data
              blocking:false
            completion:^(NSDictionary *result) {}
    ];
    NSNumber *delayMultiplier = [[Device sharedInstance] delayMultiplier];
    dispatch_async(_heartbeatQueue, ^{
        int heartbeatMaxTime = [[Settings sharedInstance] heartbeatMaxTime];
        while (heartbeatRunning) {
            // Check if time since last check-in was within 2 minutes, if not reboot device.
            sleep(15);
            NSDate *lastUpdate = [[DeviceState sharedInstance] lastUpdate];
            NSTimeInterval timeIntervalSince = [[NSDate date] timeIntervalSinceDate:lastUpdate];
            if (timeIntervalSince >= heartbeatMaxTime * [delayMultiplier intValue]) {
                syslog(@"[ERROR] HTTP SERVER DIED. Restarting...");
                [DeviceState restart];
            } else {
                //syslog(@"[INFO] Last data %f We Good", timeIntervalSince);
            }
        }
        
        // Force stop HTTP listener to prevent binding issues.
        syslog(@"[WARN] Force-stopping HTTP server.");
        [_httpServer stop];
    });
}

-(void)startPixelCheckLoop
{
    //NSDate *start = [NSDate date];
    __block bool isAgeVerification = false;
    __block bool isStartupLoggedOut = false;
    __block bool isStartup = false;
    __block bool isStartupLogo = false;
    __block bool isPassengerWarning = false;
    __block bool isWeather = false;
    __block bool isFailedLogin = false;
    __block bool isUnableAuth = false;
    __block bool isInvalidCredentials = false;
    __block bool isTos = false;
    __block bool isTosUpdate = false;
    __block bool isPrivacy = false;
    __block bool isPrivacyUpdate = false;
    __block bool isLevelUp = false;
    __block bool isPokestopOpen = false;
    __block bool isAdventureSyncRewards = false;
    __block bool isPokemonEncounter = false;
    __block bool isTeamSelect = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        isAgeVerification = [image rgbAtLocation:[[DeviceConfig sharedInstance] ageVerification]
                                      betweenMin:[[ColorOffset alloc] init:0.15 green:0.33 blue:0.17]
                                          andMax:[[ColorOffset alloc] init:0.25 green:0.43 blue:0.27]];
        isStartupLoggedOut = [image rgbAtLocation:[[DeviceConfig sharedInstance] startupLoggedOut] //0.0313726 0.796078 1 1
                                       betweenMin:[[ColorOffset alloc] init:0.95 green:0.75 blue:0.00]
                                           andMax:[[ColorOffset alloc] init:1.00 green:0.85 blue:0.10]] ||
                             [image rgbAtLocation:[[DeviceConfig sharedInstance] startupLoggedOut]
                                       betweenMin:[[ColorOffset alloc] init:0.02 green:0.78 blue:0.90]
                                           andMax:[[ColorOffset alloc] init:0.04 green:0.80 blue:1.00]];
        isStartup = [image rgbAtLocation:[[DeviceConfig sharedInstance] startup]
                              betweenMin:[[ColorOffset alloc] init:0.55 green:0.75 blue:0.00]
                                  andMax:[[ColorOffset alloc] init:0.70 green:0.90 blue:1.00]];
        isPassengerWarning = [image rgbAtLocation:[[DeviceConfig sharedInstance] passenger]
                                       betweenMin:[[ColorOffset alloc] init:0.38 green:0.75 blue:0.55]
                                           andMax:[[ColorOffset alloc] init:0.48 green:0.90 blue:0.70]];
        isWeather = [image rgbAtLocation:[[DeviceConfig sharedInstance] weather]
                              betweenMin:[[ColorOffset alloc] init:0.23 green:0.35 blue:0.50]
                                  andMax:[[ColorOffset alloc] init:0.36 green:0.47 blue:0.65]];
        isFailedLogin = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginBanned]
                                  betweenMin:[[ColorOffset alloc] init:0.39 green:0.75 blue:0.55]
                                      andMax:[[ColorOffset alloc] init:0.49 green:0.90 blue:0.70]] &&
                        [image rgbAtLocation:[[DeviceConfig sharedInstance] loginBannedText]
                                  betweenMin:[[ColorOffset alloc] init:0.26 green:0.39 blue:0.40]
                                      andMax:[[ColorOffset alloc] init:0.36 green:0.49 blue:0.50]];
        isUnableAuth = [image rgbAtLocation:[[DeviceConfig sharedInstance] unableAuthButton]
                                 betweenMin:[[ColorOffset alloc] init:0.40 green:0.78 blue:0.56]
                                     andMax:[[ColorOffset alloc] init:0.50 green:0.88 blue:0.66]] &&
                       [image rgbAtLocation:[[DeviceConfig sharedInstance] unableAuthText]
                                 betweenMin:[[ColorOffset alloc] init:0.29 green:0.42 blue:0.43]
                                     andMax:[[ColorOffset alloc] init:0.39 green:0.52 blue:0.53]];
        isInvalidCredentials = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginFailed]
                                         betweenMin:[[ColorOffset alloc] init:0.40 green:0.78 blue:0.56]
                                             andMax:[[ColorOffset alloc] init:0.50 green:0.88 blue:0.66]] &&
                               [image rgbAtLocation:[[DeviceConfig sharedInstance] loginFailedText]
                                         betweenMin:[[ColorOffset alloc] init:0.23 green:0.37 blue:0.38]
                                             andMax:[[ColorOffset alloc] init:0.33 green:0.47 blue:0.48]];
        isTos = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginTerms]
                          betweenMin:[[ColorOffset alloc] init:0.00 green:0.75 blue:0.55]
                              andMax:[[ColorOffset alloc] init:1.00 green:0.90 blue:0.70]] &&
                [image rgbAtLocation:[[DeviceConfig sharedInstance] loginTermsText]
                          betweenMin:[[ColorOffset alloc] init:0.00 green:0.00 blue:0.00]
                              andMax:[[ColorOffset alloc] init:0.30 green:0.50 blue:0.50]];
        isTosUpdate = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginTerms2]
                                betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.57]
                                    andMax:[[ColorOffset alloc] init:0.48 green:0.87 blue:0.65]] &&
                      [image rgbAtLocation:[[DeviceConfig sharedInstance] loginTerms2Text]
                                betweenMin:[[ColorOffset alloc] init:0.11 green:0.35 blue:0.44]
                                    andMax:[[ColorOffset alloc] init:0.18 green:0.42 blue:0.51]];
        isPrivacy = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginPrivacy]
                              betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.60]
                                  andMax:[[ColorOffset alloc] init:0.50 green:0.85 blue:0.65]] &&
                    [image rgbAtLocation:[[DeviceConfig sharedInstance] loginPrivacyText]
                              betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.60]
                                  andMax:[[ColorOffset alloc] init:0.50 green:0.85 blue:0.65]];
        isPrivacyUpdate = [image rgbAtLocation:[[DeviceConfig sharedInstance] loginPrivacyUpdate]
                                    betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.60]
                                        andMax:[[ColorOffset alloc] init:0.50 green:0.85 blue:0.65]] &&
                          [image rgbAtLocation:[[DeviceConfig sharedInstance] loginPrivacyUpdateText]
                                    betweenMin:[[ColorOffset alloc] init:0.22 green:0.36 blue:0.37]
                                        andMax:[[ColorOffset alloc] init:0.32 green:0.46 blue:0.47]];
        isLevelUp = [image rgbAtLocation:[[DeviceConfig sharedInstance] closeMenu] // close: 0.588235 0.52549 0.113725 1 - fixed
                              betweenMin:[[ColorOffset alloc] init:0.10 green:0.52 blue:0.58]
                                  andMax:[[ColorOffset alloc] init:0.12 green:0.53 blue:0.60]];
        isPokestopOpen = [image rgbAtLocation:[[DeviceConfig sharedInstance] closeMenu] //close: 0.94902 0.984314 0.882353 1 | 0.941176 0.945098 0.917647 1 | 0.909804 0.909804 0.890196 1   0.94902 0.968627 0.886275 1
                                   betweenMin:[[ColorOffset alloc] init:0.88 green:0.89 blue:0.87] //0.898039 0.901961 0.862745 1
                                       andMax:[[ColorOffset alloc] init:0.96 green:0.99 blue:0.96]];
        isAdventureSyncRewards = [image rgbAtLocation:[[DeviceConfig sharedInstance] adventureSyncRewards]
                                           betweenMin:[[ColorOffset alloc] init:0.98 green:0.30 blue:0.45]
                                               andMax:[[ColorOffset alloc] init:1.00 green:0.50 blue:0.60]];
        isPokemonEncounter = [image rgbAtLocation:[[DeviceConfig sharedInstance] encounterPokemonRun]
                                       betweenMin:[[ColorOffset alloc] init:0.98 green:0.98 blue:0.98]
                                           andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:1.00]] &&
                             [image rgbAtLocation:[[DeviceConfig sharedInstance] encounterPokeball]
                                       betweenMin:[[ColorOffset alloc] init:0.70 green:0.05 blue:0.05]
                                           andMax:[[ColorOffset alloc] init:0.95 green:0.30 blue:0.35]];
        isTeamSelect = [image rgbAtLocation:[[DeviceConfig sharedInstance] teamSelectBackgroundL]
                                 betweenMin:[[ColorOffset alloc] init:0.00 green:0.20 blue:0.25]
                                     andMax:[[ColorOffset alloc] init:0.05 green:0.35 blue:0.35]] &&
                       [image rgbAtLocation:[[DeviceConfig sharedInstance] teamSelectBackgroundR]
                                 betweenMin:[[ColorOffset alloc] init:0.00 green:0.20 blue:0.25]
                                     andMax:[[ColorOffset alloc] init:0.05 green:0.35 blue:0.35]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    int delayMultiplier = [[[Device sharedInstance] delayMultiplier] intValue];
    if (isAgeVerification && ![[Settings sharedInstance] autoLogin]) {
        syslog(@"[INFO] Age verification screen.");
        [UIC2 ageVerification];
        [UIC2 loginAccount];
    } else if (isStartupLoggedOut && ![[Settings sharedInstance] autoLogin]) {
        syslog(@"[INFO] App started in login screen.");
        [UIC2 loginAccount];
    } else if (isStartup) {
        syslog(@"[INFO] App still in startup logged in, waiting...");
        if (![[Device sharedInstance] isLoggedIn]) {
            [[Device sharedInstance] setIsLoggedIn:true];
        }
        sleep(2 * delayMultiplier);
    } else if (isFailedLogin) {
        syslog(@"[INFO] Found failed to login screen.");
        DeviceCoordinate *switchAccount = [[DeviceConfig sharedInstance] loginBannedSwitchAccount];
        [JarvisTestCase touch:[switchAccount tapX] withY:[switchAccount tapY]];
        sleep(1 * delayMultiplier);
        //[DeviceState logout:true];
        [DeviceState logout];
        sleep(2 * delayMultiplier);
    } else if (isStartupLogo) {
        syslog(@"[INFO] Startup logo found, waiting and trying again.");
        sleep(2 * delayMultiplier);
    } else if (isUnableAuth) {
        syslog(@"[INFO] Found unable to authenticate button.");
        DeviceCoordinate *unableAuth = [[DeviceConfig sharedInstance] unableAuthButton];
        [JarvisTestCase touch:[unableAuth tapX] withY:[unableAuth tapY]];
    } else if (isInvalidCredentials) {
        syslog(@"[INFO] Invalid credentials for %@", [[Device sharedInstance] username]);
        NSMutableDictionary *invalidData = [[NSMutableDictionary alloc] init];
        invalidData[@"uuid"] = [[Device sharedInstance] uuid];
        invalidData[@"username"] = [[Device sharedInstance] username];
        invalidData[@"type"] = TYPE_ACCOUNT_INVALID_CREDENTIALS;
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:invalidData
                  blocking:true
                completion:^(NSDictionary *result) {}];
        sleep(2 * delayMultiplier);
        [DeviceState logout];
    } else if ([UIC2 isArPlusPrompt]) {
        syslog(@"[INFO] Found camera permissions prompt.");
        DeviceCoordinate *startupOldOk = [[DeviceConfig sharedInstance] startupOldOkButton];
        [JarvisTestCase touch:[startupOldOk tapX] withY:[startupOldOk tapY]];
        sleep(2 * delayMultiplier);
    } else if (isTos) {
        syslog(@"[INFO] Accepting Terms of Service prompt.")
        DeviceCoordinate *tos = [[DeviceConfig sharedInstance] loginTerms];
        [JarvisTestCase touch:[tos tapX] withY:[tos tapY]];
        sleep(2 * delayMultiplier);
    } else if (isTosUpdate) {
        syslog(@"[INFO] Accepting updated Terms of Service prompt.");
        DeviceCoordinate *tos2 = [[DeviceConfig sharedInstance] loginTerms2];
        [JarvisTestCase touch:[tos2 tapX] withY:[tos2 tapY]];
        sleep(2 * delayMultiplier);
    } else if (isPrivacy) {
        syslog(@"[INFO] Accepting Privacy Policy prompt");
        DeviceCoordinate *privacy = [[DeviceConfig sharedInstance] loginPrivacy];
        [JarvisTestCase touch:[privacy tapX] withY:[privacy tapY]];
        sleep(2 * delayMultiplier);
    } else if (isPrivacyUpdate) {
        syslog(@"[INFO] Accepting updated Privacy Policy prompt.");
        DeviceCoordinate *privacyUpdate = [[DeviceConfig sharedInstance] loginPrivacyUpdate];
        [JarvisTestCase touch:[privacyUpdate tapX] withY:[privacyUpdate tapY]];
        sleep(2 * delayMultiplier);
    } else if ([UIC2 isStartupPrompt]) {
        syslog(@"[INFO] Found startup prompt.");
        sleep(1 * delayMultiplier);
        syslog(@"[INFO] Closing news.");
        DeviceCoordinate *closeNews = [[DeviceConfig sharedInstance] closeNews];
        [JarvisTestCase touch:[closeNews tapX] withY:[closeNews tapY]];
        sleep(2 * delayMultiplier);
        [UIC2 openNearbyTracker];
        if (!_dataStarted) {
            _dataStarted = true;
            [[JobController sharedInstance] getJobs];
        }
        sleep(2 * delayMultiplier);
    } else if (isPassengerWarning) {
        syslog(@"[INFO] Found passenger warning.");
        DeviceCoordinate *passenger = [[DeviceConfig sharedInstance] passenger];
        [JarvisTestCase touch:[passenger tapX] withY:[passenger tapY]];
        sleep(2 * delayMultiplier);
        [UIC2 openNearbyTracker];
    } else if (isWeather) {
        syslog(@"[INFO] Found weather alert.");
        DeviceCoordinate *closeWeather1 = [[DeviceConfig sharedInstance] closeWeather1];
        [JarvisTestCase touch:[closeWeather1 tapX] withY:[closeWeather1 tapY]];
        sleep(2 * delayMultiplier);
        DeviceCoordinate *closeWeather2 = [[DeviceConfig sharedInstance] closeWeather2];
        [JarvisTestCase touch:[closeWeather2 tapX] withY:[closeWeather2 tapX]];
        sleep(2 * delayMultiplier);
    } else if ([UIC2 isMainScreen]) {
        //syslog(@"[INFO] Found main screen.");
        sleep(1 * delayMultiplier);
        if (!_dataStarted) {
            _dataStarted = true;
            [[JobController sharedInstance] getJobs];
        }
    } else if ([UIC2 isTutorial]) {
        syslog(@"[INFO] Found tutorial screen.");
        [UIC2 doTutorialSelection];
    } else if ([UIC2 isTutorial2]) {
        syslog(@"[INFO] Found tutorial 2 (Pokemon) screen.");
        [UIC2 doTutorialPokemonSelection];
    } else if ([UIC2 isTutorial3]) {
        syslog(@"[INFO] Found tutorial 3 (Username) screen.");
        [UIC2 doTutorialUsernameSelection];
        sleep(1 * delayMultiplier);
    } else if ([UIC2 isTutorial4]) {
        syslog(@"[INFO] Found tutorial 4 (Pokestop) screen.");
        [UIC2 doTutorialPokestopSelection];
        sleep(1 * delayMultiplier);
    } else if ([UIC2 isBanned]) {
        syslog(@"[INFO] Found banned screen. Restarting...");
        NSMutableDictionary *bannedData = [[NSMutableDictionary alloc] init];
        bannedData[@"uuid"] = [[Device sharedInstance] uuid];
        bannedData[@"username"] = [[Device sharedInstance] username];
        bannedData[@"type"] = TYPE_ACCOUNT_BANNED;
        [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                      dict:bannedData
                  blocking:true
                completion:^(NSDictionary *result) {}];
        sleep(2 * delayMultiplier);
        [[Device sharedInstance] setUsername:nil];
        [DeviceState restart];
    } else if ([UIC2 isWarningScreen]) {
        syslog(@"[INFO] Found warning pop-up.");
        DeviceCoordinate *closeWarning = [[DeviceConfig sharedInstance] closeWarning];
        [JarvisTestCase touch:[closeWarning tapX] withY:[closeWarning tapY]];
        sleep(2 * delayMultiplier);
    } else if ([[Device sharedInstance] isLoggedIn] &&
               (isLevelUp || isPokestopOpen) &&
               (([[Settings sharedInstance] nearbyTracker] && ![UIC2 isTracker]) || ![[Settings sharedInstance] nearbyTracker])) {
        syslog(@"[INFO] Found level up/Pokestop open/badge screen.");
        DeviceCoordinate *closeMenu = [[DeviceConfig sharedInstance] closeMenu];
        [JarvisTestCase touch:[closeMenu tapX] withY:[closeMenu tapY]];
        sleep(2 * delayMultiplier);
    } else if (isAdventureSyncRewards) {
        syslog(@"[INFO] Found Adventure sync rewards pop-up.");
        DeviceCoordinate *advSyncButton = [[DeviceConfig sharedInstance] adventureSyncButton];
        if ([UIC2 isAtPixel:advSyncButton
                 betweenMin:[[ColorOffset alloc] init:0.40 green:0.80 blue:0.50]
                     andMax:[[ColorOffset alloc] init:0.50 green:0.90 blue:0.70]]) {
            [JarvisTestCase touch:[advSyncButton tapX] withY:[advSyncButton tapY]];
            sleep(2 * delayMultiplier);
            [JarvisTestCase touch:[advSyncButton tapX] withY:[advSyncButton tapY]];
        } else if ([UIC2 isAtPixel:advSyncButton
                        betweenMin:[[ColorOffset alloc] init:0.05 green:0.45 blue:0.50]
                            andMax:[[ColorOffset alloc] init:0.20 green:0.60 blue:0.65]]) {
            [JarvisTestCase touch:[advSyncButton tapX] withY:[advSyncButton tapY]];
        }
        sleep(2 * delayMultiplier);
    } else if (isPokemonEncounter) {
        syslog(@"[INFO] Oopsie, must have clicked a Pokemon, exiting encounter.");
        DeviceCoordinate *encounterRun = [[DeviceConfig sharedInstance] encounterPokemonRun];
        [JarvisTestCase touch:[encounterRun tapX] withY:[encounterRun tapY]];
        sleep(2 * delayMultiplier);
    } else if (isTeamSelect) {
        syslog(@"[INFO] Looks like we don't have a team and clicked a gym, starting team selection.");
        DeviceCoordinate *teamSelectNext = [[DeviceConfig sharedInstance] teamSelectNext];
        for (int i = 0; i < 6; i++) {
            [JarvisTestCase touch:[teamSelectNext tapX] withY:[teamSelectNext tapY]];
            sleep(1 * delayMultiplier);
        }
        sleep(3 * delayMultiplier);
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 5; j++) {
                [JarvisTestCase touch:[teamSelectNext tapX] withY:[teamSelectNext tapY]];
                sleep(1 * delayMultiplier);
            }
            sleep(4 * delayMultiplier);
        }
        
        double tapMultiplier = [DeviceConfig tapMultiplier];
        int x = arc4random_uniform([UIScreen mainScreen].bounds.size.width);
        int teamSelectY = [[DeviceConfig sharedInstance] teamSelectY];
        [JarvisTestCase touch:x * tapMultiplier withY:teamSelectY * tapMultiplier];
        sleep(3 * delayMultiplier);
        [JarvisTestCase touch:[teamSelectNext tapX] withY:[teamSelectNext tapY]];
        sleep(2 * delayMultiplier);
        DeviceCoordinate *welcomeOk = [[DeviceConfig sharedInstance] teamSelectWelcomeOk];
        [JarvisTestCase touch:[welcomeOk tapX] withY:[welcomeOk tapY]];
        syslog(@"[INFO] Team selection finished.");
        sleep(2 * delayMultiplier);
    } else {
        //syslog(@"[WARN] Nothing found");
        sleep(5);
        //loop = true;
    }
    
    //syslog(@"[VERBOSE] Pixel check loop took %f seconds", [[NSDate date] timeIntervalSinceDate:start]);
    [self startPixelCheckLoop];
}

+(void)ageVerification
{
    int delayMultiplier = [[[Device sharedInstance] delayMultiplier] intValue];
    // Click Year selector
    syslog(@"[DEBUG] Is age verification, selecting year selector");
    DeviceCoordinate *ageVerificationYear = [[DeviceConfig sharedInstance] ageVerificationYear];
    [JarvisTestCase touch:[ageVerificationYear tapX]
                    withY:[ageVerificationYear tapY]];
    sleep(1 * delayMultiplier);
    // Click very last year which passes age verification, '2007'
    syslog(@"[DEBUG] Tapping year 2007");
    DeviceCoordinate *ageVerificationYear2007 = [[DeviceConfig sharedInstance] ageVerificationYear2007];
    [JarvisTestCase touch:[ageVerificationYear2007 tapX]
                    withY:[ageVerificationYear2007 tapY]];
    sleep(1 * delayMultiplier);
    // Confirm age verification
    syslog(@"[DEBUG] Tapping age verification confirmation button");
    DeviceCoordinate *ageVerification = [[DeviceConfig sharedInstance] ageVerification];
    [JarvisTestCase touch:[ageVerification tapX]
                    withY:[ageVerification tapY]];
    sleep(1 * delayMultiplier);
}

+(void)loginAccount
{
    int delayMultiplier = [[[Device sharedInstance] delayMultiplier] intValue];
    sleep(1 * delayMultiplier);
    
    // Click 'New Player' button
    DeviceCoordinate *loginNewPlayer = [[DeviceConfig sharedInstance] loginNewPlayer];
    syslog(@"[DEBUG Tapping new player button %@", loginNewPlayer);
    [JarvisTestCase touch:[loginNewPlayer tapX]
                    withY:[loginNewPlayer tapY]];
    sleep(2 * delayMultiplier);
    
    // Click Pokemon Trainer Club button
    DeviceCoordinate *loginPTC = [[DeviceConfig sharedInstance] loginPTC];
    syslog(@"[DEBUG] Tapping PTC button %@", loginPTC);
    [JarvisTestCase touch:[loginPTC tapX]
                    withY:[loginPTC tapY]];
    sleep(2 * delayMultiplier);
    
    // Click Username text field
    DeviceCoordinate *loginUsernameTextfield = [[DeviceConfig sharedInstance] loginUsernameTextfield];
    syslog(@"[DEBUG] Tapping username text field %@", loginUsernameTextfield);
    [JarvisTestCase touch:[loginUsernameTextfield tapX]
                    withY:[loginUsernameTextfield tapY]];
    sleep(2 * delayMultiplier);
    
    // Type account username
    [Jarvis__ typeUsername];
    sleep(2 * delayMultiplier);
    
    // Click Password text field
    DeviceCoordinate *loginPasswordTextfield = [[DeviceConfig sharedInstance] loginPasswordTextfield];
    syslog(@"[DEBUG] Tappng password text field %@", loginPasswordTextfield);
    [JarvisTestCase touch:[loginPasswordTextfield tapX]
                    withY:[loginPasswordTextfield tapY]];
    sleep(2 * delayMultiplier);
    
    // Type account password
    [Jarvis__ typePassword];
    sleep(2 * delayMultiplier);
    
    // Click Config login button
    DeviceCoordinate *loginConfirm = [[DeviceConfig sharedInstance] loginConfirm];
    syslog(@"[DEBUG] Tapping confirm login %@", loginConfirm);
    [JarvisTestCase touch:[loginConfirm tapX]
                    withY:[loginConfirm tapY]];
    sleep(2 * delayMultiplier);
}

+(void)doTutorialSelection
{
    syslog(@"[INFO] [TUT] Starting tutorial for account %@", [[Device sharedInstance] username]);

    int delayMultiplier = [[[Device sharedInstance] delayMultiplier] intValue];
    syslog(@"[INFO] [TUT] Tapping 9 times passed Professor Willow screen.");
    DeviceCoordinate *willowPrompt = [[DeviceConfig sharedInstance] tutorialWillowPrompt];
    for (int i = 0; i < 9; i++) {
        [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
        sleep(2 * delayMultiplier);
    }
    sleep(2 * delayMultiplier);
    syslog(@"[INFO] [TUT] Selecting female gender.");
    DeviceCoordinate *genderFemale = [[DeviceConfig sharedInstance] tutorialGenderFemale];
    [JarvisTestCase touch:[genderFemale tapX] withY:[genderFemale tapY]];
    sleep(1 * delayMultiplier);
    syslog(@"[INFO] [TUT] Tapping next button 3 times.");
    DeviceCoordinate *tutorialStyleConfirm = [[DeviceConfig sharedInstance] tutorialStyleConfirm];
    DeviceCoordinate *tutorialNext = [[DeviceConfig sharedInstance] tutorialNext];
    // If not style confirmation button, keep clicking next.
    while (![self isAtPixel:tutorialStyleConfirm
                 betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.47 green:0.86 blue:0.63]]) {
        [JarvisTestCase touch:[tutorialNext tapX] withY:[tutorialNext tapY]];
        sleep(1 * delayMultiplier);
    }
    sleep(2 * delayMultiplier);
    syslog(@"[INFO] [TUT] Confirming style selection.");
    [JarvisTestCase touch:[tutorialStyleConfirm tapX] withY:[tutorialStyleConfirm tapY]];
    sleep(2 * delayMultiplier);

    // TODO: Block Until Clicked/pixel check method
    syslog(@"[INFO] [TUT] Willow prompt, tapping 2 times.");
    for (int i = 0; i < 3; i++) {
        [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
        sleep(2 * delayMultiplier);
    }
    sleep(3 * delayMultiplier);
    int failed = 0;
    int maxFails = 5;
    while (![self findAndClickPokemon]) {
        syslog(@"[WARN] [TUT] Failed to find Pokemon, rotating...");
        DeviceCoordinate *ageStart = [[DeviceConfig sharedInstance] ageVerificationDragStart];
        DeviceCoordinate *ageEnd = [[DeviceConfig sharedInstance] ageVerificationDragEnd];
        [JarvisTestCase drag:ageStart toPoint:ageEnd];
        sleep(5 * delayMultiplier);
        failed++;
        if (failed >= maxFails) {
            break;
        }
    }
    if (failed >= maxFails) {
        syslog(@"[ERROR] [TUT] Failed to find and click Pokemon to catch...");
        return;
    }
    sleep(4 * delayMultiplier);
    // Check for camera permissions prompt.
    syslog(@"[DEBUG] [TUT] Checking for AR(+) camera permissions prompt...");
    bool isArPrompt = [self isArPlusPrompt];
    if (isArPrompt) {
        syslog(@"[INFO] [TUT] Found AR(+) prompt, clicking.");
        DeviceCoordinate *startupOldCoordinate = [[DeviceConfig sharedInstance] startupOldOkButton];
        [JarvisTestCase touch:[startupOldCoordinate tapX] withY:[startupOldCoordinate tapY]];
        sleep(2 * delayMultiplier);
    }
    // TODO: Verify isArPlusModePrompt works.
    if (![self isArPlusModePrompt]) {
        syslog(@"[INFO] No AR(+) enabled.");
    }
    sleep(3 * delayMultiplier);
    // If we haven't hit the post capture prompt yet, keep attempting to throw pokeballs.
    //0.611765 0.839216 0.466667 1
    //0.611765 0.839216 0.462745 1
    while (![self isAtPixel:[[DeviceConfig sharedInstance] tutorialCatchConfirm] // passenger / 0.988235 1 0.988235 1
                 betweenMin:[[ColorOffset alloc] init:0.60 green:0.82 blue:0.45] // catchConfirm / 0.611765 0.839216 0.466667 1
                     andMax:[[ColorOffset alloc] init:0.63 green:0.85 blue:0.48]] &&
           ![self isAtPixel:[[DeviceConfig sharedInstance] tutorialCatchConfirm]
                 betweenMin:[[ColorOffset alloc] init:0.45 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.48 green:0.85 blue:0.63]]) {
        syslog(@"[INFO] [TUT] Attempting to throw Pokeball.");
        DeviceCoordinate *ageStart = [[DeviceConfig sharedInstance] ageVerificationDragStart];
        DeviceCoordinate *ageEnd = [[DeviceConfig sharedInstance] ageVerificationDragEnd];
        [JarvisTestCase drag:ageStart toPoint:ageEnd];
        syslog(@"[INFO] [TUT] Pokeball thrown.");
        sleep(10);
    }
    syslog(@"[INFO] [TUT] Pokemon caught!");
    sleep(2 * delayMultiplier);
    //310x755 - 0.611765 0.839216 0.466667
    syslog(@"[INFO] [TUT] Tapping OK after Pokemon caught button and waiting 10 seconds.");
    DeviceCoordinate *catchConfirm = [[DeviceConfig sharedInstance] tutorialCatchConfirm];
    [JarvisTestCase touch:[catchConfirm tapX] withY:[catchConfirm tapY]];
    sleep(10); // TODO: Wait for pokedex animation to finish. Wait longer on 5S/6 devices.
    syslog(@"[INFO] [TUT] Closing Pokemon screen.");
    // TODO: Pixel check close button
    DeviceCoordinate *closeButton = [[DeviceConfig sharedInstance] closeMenu];
    [JarvisTestCase touch:[closeButton tapX] withY:[closeButton tapY]];
    sleep(3 * delayMultiplier);
    syslog(@"[INFO] [TUT] Willow prompt, tapping 2 times.");
    [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
    sleep(3 * delayMultiplier);
    [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
    sleep(5 * delayMultiplier);
    
    NSString *username = [[Device sharedInstance] username];
    NSString *usernameReturn = [NSString stringWithFormat:@"%@\n", username];
    /*
    int count = 0;
    long max = 15 - [username length];
    while (![UIC2 isUsernameConfirm] && count < max) {
        syslog(@"[WARN] Username %@ is not available, adding random letter", username);
        DeviceCoordinate *reenterUsername = [[DeviceConfig sharedInstance] tutorialUsernameReenter];
        [JarvisTestCase touch:[reenterUsername tapX] withY:[reenterUsername tapY]];
        sleep(2 * delayMultiplier);
        uint32_t min = (uint32_t)MIN(10, [username length]);
        char character = [username characterAtIndex: (int)arc4random_uniform(min)];
        NSString *newUsername = [NSString stringWithFormat:@"%@%c", username, character];
        if ([newUsername length] > 15) {
            // Too long of a username
        }
    }
    */
    
    syslog(@"[INFO] [TUT] Typing in nickname %@", username)
    [JarvisTestCase type:usernameReturn];
    sleep(1 * delayMultiplier);
    // TODO: While not tutorialStyleConfirm button keep trying to enter random username and click OK button on fail.
    // Click OK button.
    if ([self isPassengerWarning]) {
        syslog(@"[INFO] [TUT] Clicking OK username button.");
        DeviceCoordinate *passenger = [[DeviceConfig sharedInstance] passenger];
        [JarvisTestCase touch:[passenger tapX] withY:[passenger tapY]];
    }
    sleep(2 * delayMultiplier);
    // Confirm username.
    syslog(@"[INFO] [TUT] Confirming username.");
    DeviceCoordinate *confirm = [[DeviceConfig sharedInstance] tutorialStyleConfirm];
    [JarvisTestCase touch:[confirm tapX] withY:[confirm tapY]];
    sleep(2 * delayMultiplier);
    // x 327-765 0.615686 0.835294 0.439216 1
    syslog(@"[INFO] [TUT] Clicking away Professor Willow screens.");
    DeviceCoordinate *pokestopConfirm = [[DeviceConfig sharedInstance] tutorialPokestopConfirm];
    while (![self isAtPixel:pokestopConfirm
                 betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.46 green:0.85 blue:0.63]]) {
        [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
        sleep(2 * delayMultiplier);
    }
    sleep(3 * delayMultiplier);
    // Click Pokestop button.
    syslog(@"[INFO] [TUT] Clicking away spin Pokestop prompt.");
    [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
    sleep(2 * delayMultiplier);
    syslog(@"[INFO] [TUT] Tutorial done!");
    NSMutableDictionary *tutData = [[NSMutableDictionary alloc] init];
    tutData[@"uuid"] = [[Device sharedInstance] uuid];
    tutData[@"username"] = [[Device sharedInstance] username];
    tutData[@"type"] = TYPE_TUTORIAL_DONE;
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:tutData
              blocking:true
            completion:^(NSDictionary *result) {}];
}

+(void)doTutorialPokemonSelection
{
    int delayMultiplier = [[[Device sharedInstance] delayMultiplier] intValue];
    syslog(@"[INFO] [TUT] Tapping 2 times passed Professor Willow screen.");
    DeviceCoordinate *willowPrompt = [[DeviceConfig sharedInstance] tutorialWillowPrompt];
    [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
    sleep(1 * delayMultiplier);
    [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
    sleep(3 * delayMultiplier);

    int failed = 0;
    int maxFails = 5;
    while (![self findAndClickPokemon]) {
        syslog(@"[WARN] [TUT] Failed to find Pokemon, rotating...");
        DeviceCoordinate *ageStart = [[DeviceConfig sharedInstance] ageVerificationDragStart];
        DeviceCoordinate *ageEnd = [[DeviceConfig sharedInstance] ageVerificationDragEnd];
        [JarvisTestCase drag:ageStart toPoint:ageEnd];
        sleep(5 * delayMultiplier);
        failed++;
        if (failed >= maxFails) {
            break;
        }
    }
    if (failed >= maxFails) {
        syslog(@"[ERROR] [TUT] Failed to find and click Pokemon to catch...");
        return;
    }
    sleep(4 * delayMultiplier);
    // Check for camera permissions prompt.
    syslog(@"[DEBUG] [TUT] Checking for AR(+) camera permissions prompt...");
    bool isArPrompt = [self isArPlusPrompt];
    if (isArPrompt) {
        syslog(@"[INFO] [TUT] Found AR(+) prompt, clicking.");
        DeviceCoordinate *startupOldCoordinate = [[DeviceConfig sharedInstance] startupOldOkButton];
        [JarvisTestCase touch:[startupOldCoordinate tapX] withY:[startupOldCoordinate tapY]];
        sleep(2 * delayMultiplier);
    }
    // TODO: Verify isArPlusModePrompt works.
    if (![self isArPlusModePrompt]) {
        syslog(@"[INFO] No AR(+) enabled.");
    }
    sleep(3 * delayMultiplier);
    // If we haven't hit the post capture prompt yet, keep attempting to throw pokeballs.
    //0.611765 0.839216 0.466667 1
    //0.611765 0.839216 0.462745 1
    while (![self isAtPixel:[[DeviceConfig sharedInstance] tutorialCatchConfirm] // passenger / 0.988235 1 0.988235 1
                 betweenMin:[[ColorOffset alloc] init:0.60 green:0.82 blue:0.45] // catchConfirm / 0.611765 0.839216 0.466667 1
                     andMax:[[ColorOffset alloc] init:0.63 green:0.85 blue:0.48]] &&
           ![self isAtPixel:[[DeviceConfig sharedInstance] tutorialCatchConfirm]
                 betweenMin:[[ColorOffset alloc] init:0.45 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.48 green:0.85 blue:0.63]]) {
        syslog(@"[INFO] [TUT] Attempting to throw Pokeball.");
        DeviceCoordinate *ageStart = [[DeviceConfig sharedInstance] ageVerificationDragStart];
        DeviceCoordinate *ageEnd = [[DeviceConfig sharedInstance] ageVerificationDragEnd];
        [JarvisTestCase drag:ageStart toPoint:ageEnd];
        syslog(@"[INFO] [TUT] Pokeball thrown.");
        sleep(10);
    }
    syslog(@"[INFO] [TUT] Pokemon caught!");
    sleep(2 * delayMultiplier);
    //310x755 - 0.611765 0.839216 0.466667
    syslog(@"[INFO] [TUT] Tapping OK after Pokemon caught button and waiting 10 seconds.");
    DeviceCoordinate *catchConfirm = [[DeviceConfig sharedInstance] tutorialCatchConfirm];
    [JarvisTestCase touch:[catchConfirm tapX] withY:[catchConfirm tapY]];
    sleep(10); // TODO: Wait for pokedex animation to finish. Wait longer on 5S/6 devices.
    syslog(@"[INFO] [TUT] Closing Pokemon screen.");
    // TODO: Pixel check close button
    DeviceCoordinate *closeButton = [[DeviceConfig sharedInstance] closeMenu];
    [JarvisTestCase touch:[closeButton tapX] withY:[closeButton tapY]];
    sleep(3 * delayMultiplier);
    syslog(@"[INFO] [TUT] Willow prompt, tapping 2 times.");
    [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
    sleep(3 * delayMultiplier);
    [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
    sleep(5 * delayMultiplier);
    NSString *username = [[Device sharedInstance] username];
    NSString *usernameReturn = [NSString stringWithFormat:@"%@\n", username];
    syslog(@"[INFO] [TUT] Typing in nickname %@", username)
    [JarvisTestCase type:usernameReturn];
    sleep(1 * delayMultiplier);
    // TODO: While not tutorialStyleConfirm button keep trying to enter random username and click OK button on fail.
    // Click OK button.
    if ([self isPassengerWarning]) {
        syslog(@"[INFO] [TUT] Clicking OK username button.");
        DeviceCoordinate *passenger = [[DeviceConfig sharedInstance] passenger];
        [JarvisTestCase touch:[passenger tapX] withY:[passenger tapY]];
    }
    sleep(2 * delayMultiplier);
    // Confirm username.
    syslog(@"[INFO] [TUT] Confirming username.");
    DeviceCoordinate *confirm = [[DeviceConfig sharedInstance] tutorialStyleConfirm];
    [JarvisTestCase touch:[confirm tapX] withY:[confirm tapY]];
    sleep(2 * delayMultiplier);
    // x 327-765 0.615686 0.835294 0.439216 1
    syslog(@"[INFO] [TUT] Clicking away Professor Willow screens.");
    DeviceCoordinate *pokestopConfirm = [[DeviceConfig sharedInstance] tutorialPokestopConfirm];
    while (![self isAtPixel:pokestopConfirm
                 betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.46 green:0.85 blue:0.63]]) {
        [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
        sleep(2 * delayMultiplier);
    }
    sleep(3 * delayMultiplier);
    // Click Pokestop button.
    syslog(@"[INFO] [TUT] Clicking away spin Pokestop prompt.");
    [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
    sleep(2 * delayMultiplier);
    syslog(@"[INFO] [TUT] Tutorial done!");
    NSMutableDictionary *tutData = [[NSMutableDictionary alloc] init];
    tutData[@"uuid"] = [[Device sharedInstance] uuid];
    tutData[@"username"] = [[Device sharedInstance] username];
    tutData[@"type"] = TYPE_TUTORIAL_DONE;
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:tutData
              blocking:true
            completion:^(NSDictionary *result) {}];
}

+(void)doTutorialUsernameSelection
{
    int delayMultiplier = [[[Device sharedInstance] delayMultiplier] intValue];
    syslog(@"[INFO] [TUT] Willow prompt, tapping 2 times.");
    DeviceCoordinate *willowPrompt = [[DeviceConfig sharedInstance] tutorialWillowPrompt];
    [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
    sleep(3 * delayMultiplier);
    [JarvisTestCase touch:[willowPrompt tapX] withY:[willowPrompt tapY]];
    sleep(5 * delayMultiplier);
    NSString *username = [[Device sharedInstance] username];
    NSString *usernameReturn = [NSString stringWithFormat:@"%@\n", username];
    syslog(@"[INFO] [TUT] Typing in nickname %@", username)
    [JarvisTestCase type:usernameReturn];
    sleep(1 * delayMultiplier);
    // TODO: While not tutorialStyleConfirm button keep trying to enter random username and click OK button on fail.
    // Click OK button.
    if ([self isPassengerWarning]) {
        syslog(@"[INFO] [TUT] Clicking OK username button.");
        DeviceCoordinate *passenger = [[DeviceConfig sharedInstance] passenger];
        [JarvisTestCase touch:[passenger tapX] withY:[passenger tapY]];
    }
    sleep(2 * delayMultiplier);
    // Confirm username.
    syslog(@"[INFO] [TUT] Confirming username.");
    DeviceCoordinate *confirm = [[DeviceConfig sharedInstance] tutorialStyleConfirm];
    [JarvisTestCase touch:[confirm tapX] withY:[confirm tapY]];
    sleep(2 * delayMultiplier);
    // x 327-765 0.615686 0.835294 0.439216 1
    // TODO: Call doTutorialPokestopsSelection
    syslog(@"[INFO] [TUT] Clicking away Professor Willow screens.");
    DeviceCoordinate *pokestopConfirm = [[DeviceConfig sharedInstance] tutorialPokestopConfirm];
    while (![self isAtPixel:pokestopConfirm
                 betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.46 green:0.85 blue:0.63]]) {
        [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
        sleep(2 * delayMultiplier);
    }
    sleep(3 * delayMultiplier);
    // Click Pokestop button.
    syslog(@"[INFO] [TUT] Clicking away spin Pokestop prompt.");
    [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
    sleep(2 * delayMultiplier);
    syslog(@"[INFO] [TUT] Tutorial done!");
    NSMutableDictionary *tutData = [[NSMutableDictionary alloc] init];
    tutData[@"uuid"] = [[Device sharedInstance] uuid];
    tutData[@"username"] = [[Device sharedInstance] username];
    tutData[@"type"] = TYPE_TUTORIAL_DONE;
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:tutData
              blocking:true
            completion:^(NSDictionary *result) {}];
}

+(void)doTutorialPokestopSelection
{
    int delayMultiplier = [[[Device sharedInstance] delayMultiplier] intValue];
    syslog(@"[INFO] [TUT] Clicking away Professor Willow screens.");
    DeviceCoordinate *pokestopConfirm = [[DeviceConfig sharedInstance] tutorialPokestopConfirm];
    while (![self isAtPixel:pokestopConfirm
                 betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                     andMax:[[ColorOffset alloc] init:0.46 green:0.85 blue:0.63]]) {
        [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
        sleep(2 * delayMultiplier);
    }
    sleep(3 * delayMultiplier);
    // Click Pokestop button.
    syslog(@"[INFO] [TUT] Clicking away spin Pokestop prompt.");
    [JarvisTestCase touch:[pokestopConfirm tapX] withY:[pokestopConfirm tapY]];
    sleep(2 * delayMultiplier);
    syslog(@"[INFO] [TUT] Tutorial done!");
    NSMutableDictionary *tutData = [[NSMutableDictionary alloc] init];
    tutData[@"uuid"] = [[Device sharedInstance] uuid];
    tutData[@"username"] = [[Device sharedInstance] username];
    tutData[@"type"] = TYPE_TUTORIAL_DONE;
    [Utils postRequest:[[Settings sharedInstance] backendControllerUrl]
                  dict:tutData
              blocking:true
            completion:^(NSDictionary *result) {}];
}


#pragma mark Pixel Check Methods
// TODO: Make extension class

+(BOOL)isAtPixel:(DeviceCoordinate *)coordinate betweenMin:(ColorOffset *)min andMax:(ColorOffset *)max
{
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:coordinate
                           betweenMin:min
                               andMax:max
        ];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isStartupPrompt
{
    //syslog(@"[DEBUG] Starting startup prompt check.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startupNewCautionSign]
                      betweenMin:[[ColorOffset alloc] init:1.00 green:0.97 blue:0.60]
                          andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:0.65]] &&
            [image rgbAtLocation:[[DeviceConfig sharedInstance] startupNewButton]
                      betweenMin:[[ColorOffset alloc] init:0.28 green:0.79 blue:0.62]
                          andMax:[[ColorOffset alloc] init:0.33 green:0.85 blue:0.68]]) {
            syslog(@"[DEBUG] Clearing caution sign new startup prompt.");
            DeviceCoordinate *startupNewCoordinate = [[DeviceConfig sharedInstance] startupNewButton];
            [JarvisTestCase touch:[startupNewCoordinate tapX] withY:[startupNewCoordinate tapY]];
            result = true;
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldOkButton]
                             betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                                 andMax:[[ColorOffset alloc] init:0.47 green:0.86 blue:0.63]] &&
                   [image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldCornerTest]
                             betweenMin:[[ColorOffset alloc] init:0.15 green:0.41 blue:0.45]
                                 andMax:[[ColorOffset alloc] init:0.19 green:0.46 blue:0.49]]) {
            syslog(@"[DEBUG] Clearing 2 line long old style startup prompt.");
            DeviceCoordinate *startupOldCoordinate = [[DeviceConfig sharedInstance] startupOldOkButton];
            [JarvisTestCase touch:[startupOldCoordinate tapX] withY:[startupOldCoordinate tapY]];
            result = true;
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldOkButton]
                             betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60]
                                 andMax:[[ColorOffset alloc] init:0.47 green:0.86 blue:0.63]] &&
                   [image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldCornerTest]
                             betweenMin:[[ColorOffset alloc] init:0.99 green:0.99 blue:0.99]
                                 andMax:[[ColorOffset alloc] init:1.01 green:1.01 blue:1.01]]) {
            syslog(@"[DEBUG] Clearing 3 line long old school startup prompt.");
            DeviceCoordinate *startupOldCoordinate = [[DeviceConfig sharedInstance] startupOldOkButton];
            [JarvisTestCase touch:[startupOldCoordinate tapX] withY:[startupOldCoordinate tapY]];
            result = true;
        }
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isMainScreen
{
    //syslog(@"[DEBUG] Starting main screen check.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] closeMenu]
                           betweenMin:[[ColorOffset alloc] init:0.98 green:0.98 blue:0.98]
                               andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:1.00]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] mainScreenPokeballRed]
                           betweenMin:[[ColorOffset alloc] init:0.80 green:0.10 blue:0.17]
                               andMax:[[ColorOffset alloc] init:1.00 green:0.34 blue:0.37]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isTutorial
{
    //syslog(@"[DEBUG] Starting tutorial screen check.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] compareTutorialL]
                           betweenMin:[[ColorOffset alloc] init:0.3 green:0.5 blue:0.6]
                               andMax:[[ColorOffset alloc] init:0.4 green:0.6 blue:0.7]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] compareWarningR]
                           betweenMin:[[ColorOffset alloc] init:0.3 green:0.5 blue:0.6]
                               andMax:[[ColorOffset alloc] init:0.4 green:0.6 blue:0.7]
                 ];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

// Catch a Pokemon screen
+(BOOL)isTutorial2
{
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] compareTutorial2CheckT]
                           betweenMin:[[ColorOffset alloc] init:0.29 green:0.40 blue:0.40]
                               andMax:[[ColorOffset alloc] init:0.49 green:0.60 blue:0.60]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] compareTutorial2CheckWhite]
                           betweenMin:[[ColorOffset alloc] init:0.95 green:0.95 blue:0.95]
                               andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:1.00]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

// Username screen
+(BOOL)isTutorial3
{
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] compareTutorial2CheckY]
                           betweenMin:[[ColorOffset alloc] init:0.16 green:0.30 blue:0.30]
                               andMax:[[ColorOffset alloc] init:0.36 green:0.50 blue:0.50]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] compareTutorial2CheckWhite]
                           betweenMin:[[ColorOffset alloc] init:0.95 green:0.95 blue:0.95]
                               andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:1.00]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

// Spin a Pokestop screen
+(BOOL)isTutorial4
{
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] compareTutorial4Pokestops]
                           betweenMin:[[ColorOffset alloc] init:0.00 green:0.68 blue:0.90]
                               andMax:[[ColorOffset alloc] init:0.10 green:0.88 blue:1.00]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] compareTutorial4PokestopsWhiteBox]
                           betweenMin:[[ColorOffset alloc] init:0.95 green:0.95 blue:0.95]
                               andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:1.00]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isUsernameConfirm
{
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] tutorialUsernameConfirm]
                           betweenMin:[[ColorOffset alloc] init:0.34 green:0.73 blue:0.50]
                               andMax:[[ColorOffset alloc] init:0.54 green:0.93 blue:0.70]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isPassengerWarning
{
    //syslog(@"[DEBUG] Checking for Passenger warning.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] passenger]
                           betweenMin:[[ColorOffset alloc] init:0.00 green:0.75 blue:0.55]
                               andMax:[[ColorOffset alloc] init:1.00 green:0.90 blue:0.70]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isArPlusPrompt // Camera permissions
{
    //syslog(@"[DEBUG] Checking for AR(+) prompt.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldOkButton] // Camera pop-up is same as 3 line startup
                           betweenMin:[[ColorOffset alloc] init:0.42 green:0.82 blue:0.60] // 0.615686 0.839216 0.447059 1
                               andMax:[[ColorOffset alloc] init:0.47 green:0.86 blue:0.63]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] startupOldCornerTest]
                           betweenMin:[[ColorOffset alloc] init:0.99 green:0.99 blue:0.99] // 1 1 1 1
                               andMax:[[ColorOffset alloc] init:1.01 green:1.01 blue:1.01]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isArPlusModePrompt
{
    //syslog(@"[DEBUG] Checking for AR(+) mode prompt.");
    bool result = [self isAtPixel:[[DeviceConfig sharedInstance] checkArPeristence]
                       betweenMin:[[ColorOffset alloc] init:0.94 green:0.94 blue:0.94]
                           andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:1.00]];
    if (!result) {
        // AR mode enabled, disable
        syslog(@"[INFO] AR mode prompts detected, closing and disabling.");
        sleep(5);
        DeviceCoordinate *encounterNoAr = [[DeviceConfig sharedInstance] encounterNoAr];
        [JarvisTestCase touch:[encounterNoAr tapX] withY:[encounterNoAr tapY]];
        sleep(3);
        DeviceCoordinate *encounterNoArConfirm = [[DeviceConfig sharedInstance] encounterNoArConfirm];
        [JarvisTestCase touch:[encounterNoArConfirm tapX] withY:[encounterNoArConfirm tapY]];
        sleep(4);
        DeviceCoordinate *encounterTmp = [[DeviceConfig sharedInstance] encounterTmp];
        [JarvisTestCase touch:[encounterTmp tapX] withY:[encounterTmp tapY]];
        sleep(2);
    }
    syslog(@"[INFO] AR+ Disabled");
    return result;
}

+(BOOL)isWarningScreen
{
    //syslog(@"[DEBUG] Checking for warning screen.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        result = [image rgbAtLocation:[[DeviceConfig sharedInstance] compareWarningL]
                           betweenMin:[[ColorOffset alloc] init:0.03 green:0.07 blue:0.10]
                               andMax:[[ColorOffset alloc] init:0.07 green:0.11 blue:0.14]] &&
                 [image rgbAtLocation:[[DeviceConfig sharedInstance] compareWarningR]
                           betweenMin:[[ColorOffset alloc] init:0.03 green:0.07 blue:0.10]
                               andMax:[[ColorOffset alloc] init:0.07 green:0.11 blue:0.14]];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)isBanned
{
    return [self isAtPixel:[[DeviceConfig sharedInstance] loginBannedBackground]
                betweenMin:[[ColorOffset alloc] init:0.00 green:0.20 blue:0.30]
                    andMax:[[ColorOffset alloc] init:0.05 green:0.30 blue:0.40]
    ];
}

+(BOOL)isTracker
{
    return [self isAtPixel:[[DeviceConfig sharedInstance] trackerTopCenter] //0.980392 1 0.984314 1
                betweenMin:[[ColorOffset alloc] init:0.97 green:0.97 blue:0.97]
                    andMax:[[ColorOffset alloc] init:1.00 green:1.00 blue:1.00]] &&
           [self isAtPixel:[[DeviceConfig sharedInstance] trackerBottomCenter] //0.933333 1 0.941176 1
                betweenMin:[[ColorOffset alloc] init:0.93 green:0.98 blue:0.92]
                    andMax:[[ColorOffset alloc] init:0.95 green:1.00 blue:0.94]];
}

+(BOOL)findAndClickPokemon
{
    syslog(@"[INFO] [TUT] Starting to look for Pokemon to click.");
    __block bool result = false;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        size_t width = CGImageGetWidth([image CGImage]);
        size_t height = CGImageGetHeight([image CGImage]);
        syslog(@"[DEBUG] [TUT] Scanning Pokemon...");
        //int feetX = 324;
        //int feetY = 818;
        DeviceCoordinate *feet = [[DeviceConfig sharedInstance] tutorialPokemonAtFeet];
        UIColor *feetColor = [image getPixelColor:[feet x] withY:[feet y]];
        CGFloat red = 0;
        CGFloat green = 0;
        CGFloat blue = 0;
        CGFloat alpha = 0;
        [feetColor getRed:&red green:&green blue:&blue alpha:&alpha];
        double tapMultiplier = [DeviceConfig tapMultiplier];
        syslog(@"[DEBUG] [TUT] Checking if Pokemon at feet.");
        if (red > 0.9 &&
            green > 0.6 && green < 0.8 && //0.7
            blue > 0.3 && blue < 0.5) { //0.4
            double locX = lround([feet x]) * tapMultiplier;
            double locY = lround([feet y]) * tapMultiplier;
            NSLog(@"[Jarvis] [INFO] [TUT] Pokemon found at feet! Attempting to click at %f, %f", locX, locY);
            [JarvisTestCase touch:locX withY:locY];
            result = true;
            dispatch_semaphore_signal(sem);
        }
        // Start a little away from the edge of the screen.
        for (int x = 8; x < width / 10; x++) {
            // Start about half way down the screen.
            for (int y = 40; y < height / 10; y++) {
                int realX = x * 10;
                int realY = y * 10;
                UIColor *color = [image getPixelColor:realX withY:realY];
                CGFloat red = 0;
                CGFloat green = 0;
                CGFloat blue = 0;
                CGFloat alpha = 0;
                [color getRed:&red green:&green blue:&blue alpha:&alpha];
                //NSLog(@"[Jarvis] [DEBUG] [TUT] Pixel: [x=%d y=%d] red=%f green=%f blue=%f alpha=%f", realX, realY, red, green, blue, alpha);
                if (red > 0.9 &&
                    green > 0.6 && green < 0.8 && //0.7
                    blue > 0.3 && blue < 0.5) { //0.4
                    double locX = lround(realX) * tapMultiplier;
                    double locY = lround(realY) * tapMultiplier;
                    syslog(@"[INFO] [TUT] Pokemon found! Attempting to click at %f, %f", locX, locY);
                    [JarvisTestCase touch:locX withY:locY];
                    result = true;
                    dispatch_semaphore_signal(sem);
                    break;
                }
                sleep(0.5);
            }
        }
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(NSNumber *)hasEgg
{
    __block NSNumber *result = @0;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [Utils takeScreenshot];
        ColorOffset *eggMin = [[ColorOffset alloc] init:0.45 green:0.60 blue:0.65];
        ColorOffset *eggMax = [[ColorOffset alloc] init:0.60 green:0.70 blue:0.75];
        ColorOffset *giftMin = [[ColorOffset alloc] init:0.60 green:0.05 blue:0.50];
        ColorOffset *giftMax = [[ColorOffset alloc] init:0.70 green:0.15 blue:0.75];
        if ([image rgbAtLocation:[[DeviceConfig sharedInstance] itemEgg] betweenMin:eggMin andMax:eggMax] &&
            ![image rgbAtLocation:[[DeviceConfig sharedInstance] itemEgg] betweenMin:giftMin andMax:giftMax]) {
            result = @1; // First item slot
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] itemEgg2] betweenMin:eggMin andMax:eggMax] &&
                   ![image rgbAtLocation:[[DeviceConfig sharedInstance] itemEgg2] betweenMin:giftMin andMax:giftMax]) {
            result = @2; // Second item slot
        } else if ([image rgbAtLocation:[[DeviceConfig sharedInstance] itemEgg3] betweenMin:eggMin andMax:eggMax] &&
                   ![image rgbAtLocation:[[DeviceConfig sharedInstance] itemEgg3] betweenMin:giftMin andMax:giftMax]) {
            result = @3; // Third item slot
        }
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+(BOOL)eggDeploy
{
    syslog(@"[INFO] Deploying lucky egg...");
    bool result = false;
    if (![[Settings sharedInstance] deployEggs]) {
        return result;
    }
    
    DeviceCoordinate *closeMenu = [[DeviceConfig sharedInstance] closeMenu];
    // Check if not the main screen, tracker menu likely open, close it.
    //while (![self isMainScreen]) {
    if (![self isMainScreen]) {
        // TODO: Close passenger too?
        [JarvisTestCase touch:[closeMenu tapX] withY:[closeMenu tapY]];
        sleep(1);
    }
    
    if ([self isAtPixel:[[DeviceConfig sharedInstance] activeEgg] //0.94902 1 0.956863 1
             betweenMin:[[ColorOffset alloc] init:0.7 green:0.8 blue:0.9]
                 andMax:[[ColorOffset alloc] init:0.8 green:0.9 blue:1.0]] ||
        [self isAtPixel:[[DeviceConfig sharedInstance] activeEgg]
             betweenMin:[[ColorOffset alloc] init:0.94 green:0.90 blue:0.94]
                 andMax:[[ColorOffset alloc] init:0.96 green:1.01 blue:0.96]]) {
        syslog(@"[INFO] Lucky egg already active, skipping deployment.");
        return result;
    }
    
    // Open main menu
    [JarvisTestCase touch:[closeMenu tapX] withY:[closeMenu tapY]];
    sleep(1);
    
    // Open items menu
    DeviceCoordinate *openItems = [[DeviceConfig sharedInstance] openItems];
    [JarvisTestCase touch:[openItems tapX] withY:[openItems tapY]];
    sleep(1);
    
    // If egg wasn't found in 1st, 2nd, or 3rd item slot we either don't have any or one active.
    NSNumber *hasEgg = [self hasEgg];
    if ([hasEgg intValue] == 0) {
        syslog(@"[WARN] No lucky egg detected at the first 3 item slots, might already be active.");
        [JarvisTestCase touch:[closeMenu tapX] withY:[closeMenu tapY]];
        sleep(1);
        return result;
    }
    sleep(1);

    // Check which item slot it was found at.
    DeviceCoordinate *eggMenuItem;
    switch ([hasEgg intValue]) {
        case 1:
            eggMenuItem = [[DeviceConfig sharedInstance] itemEgg];
            syslog(@"[DEBUG] Egg found in slot 1");
            break;
        case 2:
            eggMenuItem = [[DeviceConfig sharedInstance] itemEgg2];
            syslog(@"[DEBUG] Egg found in slot 2");
            break;
        case 3:
            eggMenuItem = [[DeviceConfig sharedInstance] itemEgg3];
            syslog(@"[DEBUG] Egg found in slot 3");
            break;
    }
    syslog(@"[DEBUG] Clicking lucky egg item at %@", eggMenuItem);
    // Click egg menu item
    [JarvisTestCase touch:[eggMenuItem tapX] withY:[eggMenuItem tapY]];
    sleep(2);
    // Touch egg to deploy
    DeviceCoordinate *eggDeploy = [[DeviceConfig sharedInstance] itemEggDeploy];
    [JarvisTestCase touch:[eggDeploy tapX] withY:[eggDeploy tapY]];
    sleep(2);
    result = true;
    syslog(@"[INFO] Deployed egg");
    
    [[Device sharedInstance] setLastEggDeployTime:[NSDate date]];
    NSNumber *luckyEggsCount = [[Device sharedInstance] luckyEggsCount];
    [[Device sharedInstance] setLuckyEggsCount:[Utils decrementInt:luckyEggsCount]];
    return result;
}

+(void)openNearbyTracker
{
    if ([[Settings sharedInstance] nearbyTracker] && ![self isTracker]) {
        syslog(@"[INFO] Opening nearby tracker.");
        DeviceCoordinate *tracker = [[DeviceConfig sharedInstance] trackerMenu];
        [JarvisTestCase touch:[tracker tapX] withY:[tracker tapY]];
        sleep(1 * [[[Device sharedInstance] delayMultiplier] intValue]);
    }
}

+(void)freeScreen
{
    
}

@end

/*
@class NSString;

@interface NIATrustedCertificatesAuthenticator : NSObject <NSURLSessionDelegate>
{
}

//-(void)URLSession:(id)arg1 didReceiveChallenge:(id)arg2 completionHandler:(CDUnknownBlockType)arg3;
-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler;

typedef void (^CDUnknownBlockType)(void);

@end

@implementation NIATrustedCertificatesAuthenticator

//-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
-(void)URLSession:(id)arg1 didReceiveChallenge:(id)arg2 completionHandler:(id)arg3
{
    // Trust invalid certs
    NSLog(@"[Jarvis] [DEBUG] URLSession: %@, Challenge: %@", arg1, arg2);
    ////NSURLCredential *credential = [NSURLCredential credentialForTrust:arg2.protectionSpace.serverTrust];
    //NSLog(@"[Jarvis] [DEBUG] Credentials Username: %@ Password: %@", [credential user], [credential password]);
    //completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}

@end
*/

/*
 %hook NIATrustedCertificatesAuthenticator
 -(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {

     NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
     completionHandler(NSURLSessionAuthChallengeUseCredential, credential);

 }
 %end
*/
