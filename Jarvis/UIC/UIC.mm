//
//  UIC.cpp
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#include "UIC.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/utsname.h>

#include <string>
#include <sstream>
#include <iostream>
#include <vector>

// Objective-C
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIDevice.h>

//#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "../GCD/GCDAsyncSocket.h"

// Listener
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>

// Misc
#include <math.h>
//#include <curl/curl.h>

using namespace std;

// TODO: Remote config

static BOOL _firststart = true;
static BOOL _startup = true;

static NSString *_backend = @"http://10.0.1.100:9001";
static NSString *_backendControllerUrl = [_backend stringByAppendingString:@"/controler"];
static NSString *_backendRawUrl = [_backend stringByAppendingString:@"/raw"];
static NSString *_localUrl = @"http://localhost:8080/loc";
static NSString *_uuid = [[UIDevice currentDevice] name];
static NSString *_modelName; //[[UIDevice currentDevice] localizedModel];
static NSString *_osName = [[UIDevice currentDevice] systemName];
static NSString *_osVersion = [[UIDevice currentDevice] systemVersion];
static BOOL _started = false;
static CLLocation *_currentLocation;
static BOOL _waitRequiresPokemon = false;
static BOOL _waitForData = false;
//lock = NSLock();
static NSDate *_firstWarningDate; // ctime(time(&0))
static NSNumber *_jitterCorner = @0;
static BOOL _gotQuest = false;
static BOOL _gotIV = false;
static NSNumber *_noQuestCount = @0;
static NSNumber *_noEncounterCount = @0;
static NSNumber *_targetMaxDistance = @250.0;
static NSNumber *_emptyGmoCount = @0;
static NSString *_pokemonEncounterId;
static NSString *_action;
static NSNumber *_encounterDistance = @0.0;
static NSNumber *_encounterDelay = @0.0;
static void* _image; // UIImage
static NSNumber *_level = @0;
static NSString *_ptcToken__hgj; // Load from UserDefaults (5750bac0-483c-4131-80fd-6b047b2ca7b4)
static BOOL _menuButton__hgj = false;
static BOOL _menuButton2__hgj = false;
static NSString *_neededButton = @"";
static BOOL _okButton__hgj = false;
static BOOL _newPlayerButton__hgj = false;
static BOOL _bannedScreen__hgj = false;
static BOOL _invalidScreen__hgj = false;
//string loggingUrl = "";
//string loggingPort = 80;
//string loggingUseTls = true;
static NSNumber *_startupLat = @0.0;
static NSNumber *_startupLon = @0.0;
static CLLocation *_startupLocation;
static NSNumber *_lastEncounterLat = @0.0;
static NSNumber *_lastEncounterLon = @0.0;
static NSDate *_lastUpdate;
static BOOL _delayQuest = false;
static BOOL _gotQuestEarly = false;
static NSString *_friendName = @"";

// TODO: UIC properties
static BOOL _shouldExit;
static NSString *_username;
static NSString *_password;
static BOOL _newLogIn;
static BOOL _isLoggedIn;
static BOOL _newCreated;
static BOOL _needsLogout;
static NSNumber *_minLevel = @0;
static NSNumber *_maxLevel = @(29);
static NSNumber *_deviceMultiplier__hgj = @5.0; // 5S/6/6+ 45 else 5.0

static NSString *_response_200 = @"HTTP/1.1 200 OK\nContent-Type: text/json; charset=utf-8\n\n";
static NSString *_response_400 = @"HTTP/1.1 400 Bad Request\nContent-Type: text/json; charset=utf-8\n\n";
static NSString *_response_404 = @"HTTP/1.1 404 Not Found\nContent-Type: text/json; charset=utf-8\n\n";

static double _baseHorizontalAccuracy = 200.0; // in meters
static double _baseVerticalAccuracy = 200.0; // in meters

static NSString* getModelIdentifier() {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

static NSString* modelIdentifierToName(NSString* identifier) {
    if ([identifier isEqualToString:@"iPod5,1"]) { return @"iPod touch (5th generation)"; }
    else if ([identifier isEqualToString:@"iPod7,1"]) { return @"iPod touch (6th generation)"; }
    else if ([identifier isEqualToString:@"iPod9,1"]) { return @"iPod touch (7th generation)"; }
    else if ([identifier isEqualToString:@"iPhone3,1"] || [identifier isEqualToString:@"iPhone3,2"] || [identifier isEqualToString:@"iPhone3,3"]) { return @"iPhone 4"; }
    else if ([identifier isEqualToString:@"iPhone4,1"]) { return @"iPhone 4s"; }
    else if ([identifier isEqualToString:@"iPhone5,1"] || [identifier isEqualToString:@"iPhone5,2"]) { return @"iPhone 5"; }
    else if ([identifier isEqualToString:@"iPhone5,3"] || [identifier isEqualToString:@"iPhone5,4"]) { return @"iPhone 5c"; }
    else if ([identifier isEqualToString:@"iPhone6,1"] || [identifier isEqualToString:@"iPhone6,2"]) { return @"iPhone 5s"; }
    else if ([identifier isEqualToString:@"iPhone7,2"]) { return @"iPhone 6"; }
    else if ([identifier isEqualToString:@"iPhone7,1"]) { return @"iPhone 6 Plus"; }
    else if ([identifier isEqualToString:@"iPhone8,1"]) { return @"iPhone 6s"; }
    else if ([identifier isEqualToString:@"iPhone8,2"]) { return @"iPhone 6s Plus"; }
    else if ([identifier isEqualToString:@"iPhone9,1"] || [identifier isEqualToString:@"iPhone9,3"]) { return @"iPhone 7"; }
    else if ([identifier isEqualToString:@"iPhone9,2"] || [identifier isEqualToString:@"iPhone9,4"]) { return @"iPhone 7 Plus"; }
    else if ([identifier isEqualToString:@"iPhone8,4"]) { return @"iPhone SE"; }
    else if ([identifier isEqualToString:@"iPhone10,1"] || [identifier isEqualToString:@"iPhone10,4"]) { return @"iPhone 8"; }
    else if ([identifier isEqualToString:@"iPhone10,2"] || [identifier isEqualToString:@"iPhone10,5"]) { return @"iPhone 8 Plus"; }
    else if ([identifier isEqualToString:@"iPhone10,3"] || [identifier isEqualToString:@"iPhone10,6"]) { return @"iPhone X"; }
    else if ([identifier isEqualToString:@"iPhone11,2"]) { return @"iPhone XS"; }
    else if ([identifier isEqualToString:@"iPhone11,4"] || [identifier isEqualToString:@"iPhone11,6"]) { return @"iPhone XS Max"; }
    else if ([identifier isEqualToString:@"iPhone11,8"]) { return @"iPhone XR"; }
    else if ([identifier isEqualToString:@"iPhone12,1"]) { return @"iPhone 11"; }
    else if ([identifier isEqualToString:@"iPhone12,3"]) { return @"iPhone 11 Pro"; }
    else if ([identifier isEqualToString:@"iPhone12,5"]) { return @"iPhone 11 Pro Max"; }
    else if ([identifier isEqualToString:@"iPad2,1"] || [identifier isEqualToString:@"iPad2,2"] || [identifier isEqualToString:@"iPad2,3"] || [identifier isEqualToString:@"iPad2,4"]) { return @"iPad 2"; }
    else if ([identifier isEqualToString:@"iPad3,1"] || [identifier isEqualToString:@"iPad3,2"] || [identifier isEqualToString:@"iPad3,3"]) { return @"iPad (3rd generation)"; }
    else if ([identifier isEqualToString:@"iPad3,4"] || [identifier isEqualToString:@"iPad3,5"] || [identifier isEqualToString:@"iPad3,6"]) { return @"iPad (4th generation)"; }
    else if ([identifier isEqualToString:@"iPad6,11"] || [identifier isEqualToString:@"iPad6,12"]) { return @"iPad (5th generation)"; }
    else if ([identifier isEqualToString:@"iPad7,5"] || [identifier isEqualToString:@"iPad7,6"]) { return @"iPad (6th generation)"; }
    else if ([identifier isEqualToString:@"iPad7,11"] || [identifier isEqualToString:@"iPad7,12"]) { return @"iPad (7th generation)"; }
    else if ([identifier isEqualToString:@"iPad4,1"] || [identifier isEqualToString:@"iPad4,2"] || [identifier isEqualToString:@"iPad4,3"]) { return @"iPad Air"; }
    else if ([identifier isEqualToString:@"iPad5,3"] || [identifier isEqualToString:@"iPad5,4"]) { return @"iPad Air 2"; }
    else if ([identifier isEqualToString:@"iPad11,4"] || [identifier isEqualToString:@"iPad11,5"]) { return @"iPad Air (3rd generation)"; }
    else if ([identifier isEqualToString:@"iPad2,5"] || [identifier isEqualToString:@"iPad2,6"] || [identifier isEqualToString:@"iPad2,7"]) { return @"iPad mini"; }
    else if ([identifier isEqualToString:@"iPad4,4"] || [identifier isEqualToString:@"iPad4,5"] || [identifier isEqualToString:@"iPad4,6"]) { return @"iPad mini 2"; }
    else if ([identifier isEqualToString:@"iPad4,7"] || [identifier isEqualToString:@"iPad4,8"] || [identifier isEqualToString:@"iPad4,9"]) { return @"iPad mini 3"; }
    else if ([identifier isEqualToString:@"iPad5,1"] || [identifier isEqualToString:@"iPad5,2"]) { return @"iPad mini 4"; }
    else if ([identifier isEqualToString:@"iPad11,1"] || [identifier isEqualToString:@"iPad11,2"]) { return @"iPad mini (5th generation)"; }
    else if ([identifier isEqualToString:@"iPad6,3"] || [identifier isEqualToString:@"iPad6,4"]) { return @"iPad Pro (9.7-inch)"; }
    else if ([identifier isEqualToString:@"iPad6,7"] || [identifier isEqualToString:@"iPad6,8"]) { return @"iPad Pro (12.9-inch)"; }
    else if ([identifier isEqualToString:@"iPad7,1"] || [identifier isEqualToString:@"iPad7,2"]) { return @"iPad Pro (12.9-inch) (2nd generation)"; }
    else if ([identifier isEqualToString:@"iPad7,3"] || [identifier isEqualToString:@"iPad7,4"]) { return @"iPad Pro (10.5-inch)"; }
    else if ([identifier isEqualToString:@"iPad8,1"] || [identifier isEqualToString:@"iPad8,2"] || [identifier isEqualToString:@"iPad8,3"] || [identifier isEqualToString:@"iPad8,4"]) { return @"iPad Pro (11-inch)"; }
    else if ([identifier isEqualToString:@"iPad8,5"] || [identifier isEqualToString:@"iPad8,6"] || [identifier isEqualToString:@"iPad8,7"] || [identifier isEqualToString:@"iPad8,8"]) { return @"iPad Pro (12.9-inch) (3rd generation)"; }
    else if ([identifier isEqualToString:@"AppleTV5,3"]) { return @"Apple TV"; }
    else if ([identifier isEqualToString:@"AppleTV6,2"]) { return @"Apple TV 4K"; }
    else if ([identifier isEqualToString:@"AudioAccessory1,1"]) { return @"HomePod"; }
    else if ([identifier isEqualToString:@"i386"] || [identifier isEqualToString:@"x86_64"]) { return @"Simulator"; }
    return identifier;
}


@implementation UIC2

static NSNumber *_port = @(8080);

+ (NSNumber *)port {
  return _port;
}

-(id)init
{
    NSLog(@"[UIC] init");
    if ((self = [super init]))
    {
    }
    
    return self;
}

-(void *)start:(NSNumber *)port
{
    NSLog(@"[UIC] start");
    NSLog(@"[UIC] Device Uuid: %@", _uuid);
    _modelName = getModelIdentifier();
    _modelName = modelIdentifierToName(_modelName);
    NSLog(@"[UIC] Device Model: %@", _modelName);
    NSLog(@"[UIC] Device OS: %@", _osName);
    NSLog(@"[UIC] Device OS Version: %@", _osVersion);

    _port = port;
    [self start_listener:port];

    return 0;
}

-(void *)start_listener:(NSNumber *)port
{
    GCDAsyncSocket *listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![listenSocket acceptOnPort:8080 error:&error]) {
        NSLog(@"[UIC] Failed to start webserver listener on port %@:\r\nError:%@", port, error);
    }
    NSLog(@"[UIC] Listening on port %@", port);
    return 0;
}

-(void)socket:(GCDAsyncSocket *)sender didAcceptNewSocket:(nonnull GCDAsyncSocket *)newSocket
{
    // The "sender" parameter is the listenSocket we created.
    // The "newSocket" is a new instance of GCDAsyncSocket.
    // It represents the accepted incoming client connection.
    
    //NSLog(@"[UIC] New connection at %@", [newSocket connectedHost]);
    NSString *host = [newSocket connectedHost];
    UInt16 port = [newSocket connectedPort];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"[UIC] Accepted client %@:%hu", host, port);
        }
    });
    
    //NSString *welcomeMsg = @"Welcome to the AsyncSocket Echo Server";
    //NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
    //[newSocket writeData:welcomeData withTimeout:-1 tag:WELCOME_MSG];
    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    
    //NSString *response = [NSString stringWithFormat:@"%@\r\n%@", _response_200, @"Hi"];
    //[self sendData:newSocket data:response];
}

-(void)socket:(GCDAsyncSocket *)sender didReadData:(nonnull NSData *)data withTag:(long)tag
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
            NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
            if (msg) {
                NSLog(@"[UIC] Received data: %@", msg);
                NSArray *split = [msg componentsSeparatedByString:@" "];
                if ([split count] == 3) {
                    NSString *method = split[0];
                    NSString *query = split[1];
                    NSString *httpProtocol = split[2];
                    if (([method isEqualToString:@"GET"] || [method isEqualToString:@"POST"])
                    && [[httpProtocol substringWithRange:NSMakeRange(0, 4)] isEqualToString:@"HTTP"]) {
                        NSString *response = _response_404;
                        if ([query hasPrefix:@"/data"]) {
                            NSArray *querySplit = [query componentsSeparatedByString:@"?"];
                            NSDictionary *params = [self parseUrlQueryParameters:querySplit[1]];
                            NSString *dataResponse = [self handle_data:params];
                            response = [_response_200 stringByAppendingString:dataResponse];
                        } else if ([query hasPrefix:@"/loc"]) {
                            NSArray *querySplit = [query componentsSeparatedByString:@"?"];
                            NSDictionary *params = [self parseUrlQueryParameters:querySplit[1]];
                            NSString *locResponse = [self handle_location:params];
                            response = [_response_200 stringByAppendingString:locResponse];
                        } else {
                            NSLog(@"[UIC] Invalid request endpoint.");
                        }
                        [sender writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
                    }
                }
            } else {
                NSLog(@"[UIC] Error converting received data into UTF-8 String");
            }
        }
    });
}

-(NSMutableDictionary *)parseUrlQueryParameters:(NSString *)queryParameters
{
    NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
    NSArray *components = [queryParameters componentsSeparatedByString:@"&"];
    for (NSString *pair in components)
    {
        NSArray *pairComponents = [pair componentsSeparatedByString:@"="];
        NSString *key = [[pairComponents firstObject] stringByRemovingPercentEncoding];
        NSString *value = [[pairComponents lastObject] stringByRemovingPercentEncoding];

        [queryStringDictionary setObject:value forKey:key];
    }
    return queryStringDictionary;
}

-(void)sendData:(GCDAsyncSocket *)socket data:(NSString *)data
{
    NSData *msg = [data dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"[UIC] Sending data: %@", data);
    [socket writeData:msg withTimeout:-1 tag:1];
}

-(NSString *)handle_location:(NSMutableDictionary *)params {
    NSLog(@"[UIC] Got param test=%@", [params objectForKey:@"test"]);
    NSString *response = _response_200;
    return response;
}

-(NSString *)handle_data:(NSMutableDictionary *)params {
    _lastUpdate = [NSDate date];
    CLLocation *currentLoc = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(
                                _currentLocation.coordinate.latitude,
                                _currentLocation.coordinate.longitude)
                                  altitude:-1
                        horizontalAccuracy:_baseHorizontalAccuracy
                          verticalAccuracy:_baseVerticalAccuracy
                                 timestamp:[NSDate date]];
    NSNumber *targetMaxDistance = _targetMaxDistance;
    NSString *pokemonEncounterId = _pokemonEncounterId;

    if (_currentLocation == nil) {
        //return _response_200;
    }
    [params setObject:@(currentLoc.coordinate.latitude) forKey:@"lat_target"];
    [params setObject:@(currentLoc.coordinate.longitude) forKey:@"lon_target"];
    [params setObject:targetMaxDistance forKey:@"target_max_distance"];
    [params setObject:_username ?: @"" forKey:@"username"];
    [params setObject:pokemonEncounterId ?: @"" forKey:@"pokemon_encounter_id"];
    [params setObject:_uuid forKey:@"uuid"];
    [params setObject:_ptcToken__hgj ?: @"" forKey:@"ptcToken"];

    /*
    NSString *url = _backendRawUrl;
    CURL *curl;
    CURLcode res;
    string readBuffer;
    curl = curl_easy_init();
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, this->toObjCString(url));
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write_callback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
        res = curl_easy_perform(curl);
        curl_easy_cleanup(curl);
        
        string recv = readBuffer;
        if (recv.length() > 0) {
            NSMutableDictionary* result = this->toDictionary(recv);
            NSMutableDictionary* data = result[@"data"];
            bool inArea = data[@"in_area"];
            NSNumber *level = data[@"level"];// ?? 0;
            NSNumber *nearby = data[@"nearby"];// ?? 0;
            NSNumber *wild = data[@"wild"];// ?? 0;
            NSNumber *quests = data[@"quests"];// ?? 0;
            NSNumber *encounters = data[@"encounters"];// ?? 0;
            NSNumber *pokemonLat = data[@"pokemon_lat"];// ?? 0.0;
            NSNumber *pokemonLon = data[@"pokemon_lon"];// ?? 0.0;
            NSString *pokemonEncounterIdResult = data[@"pokemon_encounter_id"];
            NSNumber *targetLat = data[@"target_lat"];// ?? 0.0;
            NSNumber *targetLon = data[@"target_lon"];// ?? 0.0;
            bool onlyEmptyGmos = data[@"only_empty_gmos"];// ?? true;
            bool onlyInvalidGmos = data[@"only_invalid_gmos"];// ?? false;
            bool containsGmo = data[@"contains_gmos"];// ?? true;
            
            this->level = level;
            string toPrint;
            
            //self.lock.lock();
            float diffLat = fabs(this->currentLocation[0] - targetLat); //?? 0
            float diffLon = fabs(this->currentLocation[1] - targetLon);
            
            // TODO: MIZU tut stuff
            
            if (onlyInvalidGmos) {
                this->waitForData = false;
                toPrint = "[UIC] Got GMO but it was malformed. Skipping.";
            } else if (containsGmo) {
                if (inArea && diffLat < 0.0001 && diffLon < 0.0001) {
                    this->emptyGmoCount = 0;
                    if (this->pokemonEncounterId != NULL) {
                        if (nearby + wild > 0) {
                            if (pokemonLat != 0 && pokemonLon != 0 && this->pokemonEncounterId == pokemonEncounterIdResult) {
                                this->waitRequiresPokemon = false;
                                int oldLocation[2] = { this->currentLocation[0], this->currentLocation[1] };
                                this->currentLocation = { pokemonLat, pokemonLon };
                                int newLocation[2] = { this->currentLocation[0], this->currentLocation[1] };
                                this->encounterDistance = 0.01; // TODO: newLocation.distance(oldLocation);
                                this->pokemonEncounterId = NULL;
                                this->waitForData = false;
                                toPrint = "[UIC] Got Data and found Pokemon";
                            } else {
                                toPrint = "[UIC] Got Data but did not find Pokemon";
                            }
                        } else {
                            toPrint = "[UIC] Got Data without Pokemon";
                        }
                    } else if (this->waitRequiresPokemon) {
                        if (nearby + wild > 0) {
                            toPrint = "[UIC] Got Data with Pokemon";
                            this->waitForData = false;
                        } else {
                            toPrint = "[UIC] Got Data without Pokemon";
                        }
                    } else {
                        toPrint = "[UIC] Got Data";
                        this->waitForData = false;
                    }
                } else if (onlyEmptyGmos && !startup) {
                    this->emptyGmoCount++;
                    toPrint = "[UIC] Got Empty Data";
                } else {
                    this->emptyGmoCount = 0;
                    toPrint = "[UIC] Got Data outside Target-Area";
                }
            } else {
                toPrint = "[UIC] Got Data without GMO";
            }
            
            if (!this->gotQuest && quests != 0) {
                this->gotQuest = true;
                this->gotQuestEarly = true;
            }
            
            //self.lock.unlock();
            print(toPrint);
        }
    }
    */
    NSString *response = [NSString stringWithFormat:@"%@\r\n%@", _response_200, params];
    return response;
}

// TODO: Convert C code to ObjC and make ObjC method.
/*
static void* handle_request(void* pcliefd) {
    NSLog(@"[UIC] handle_request: %ld", (long)pcliefd);
    int cliefd = *(int*)pcliefd;
    delete (int *)pcliefd;
    
    ssize_t n;
    char buffer[255];
    const char *response;
    
    n = recv(cliefd, buffer, sizeof(buffer), 0);
    if (n < 0) {
        NSLog(@"[UIC] recv() error");
        // TODO: close cliefd?
        return 0;
    }
    
    buffer[n] = 0;
    response = string([_response_400 UTF8String]).c_str();
    NSLog(@"[UIC] recv() %s\n", buffer);
     
    string s(buffer), token;
    istringstream ss(s);
    vector<string> token_list;
    for (int i = 0; i < 3 && ss; i++) {
        ss >> token;
        NSLog(@"[UIC] token[%d] = %s\n", i, token.c_str());
        token_list.push_back(token);
    }
    
    if (token_list.size() == 3
        && (token_list[0] == "GET" || token_list[0] == "POST")
        && token_list[2].substr(0, 4) == "HTTP") {
        if (token_list[1] == "/data") {
            NSString *dataResponse = handle_data(toObjCString(s.c_str()));
            string resp = string([dataResponse UTF8String]);
            response = resp.c_str();
        } else if (token_list[1] == "/loc") {
            NSString *locResponse = handle_location(toObjCString(s.c_str()));
            string resp = string([locResponse UTF8String]);
            response = resp.c_str();
        } else {
            NSLog(@"[UIC] Invalid request endpoint.");
            response = string([_response_404 UTF8String]).c_str();
        }
    }
    
    //long length = strlen(response);
    n = write(cliefd, response, sizeof(response));
    if (n < 0) {
        NSLog(@"[UIC] write() error");
        return 0;
    }

    close(cliefd);
    return 0;
}
*/

static NSString* toObjCString(string value) {
    return [NSString stringWithCString:value.c_str() encoding:NSUTF8StringEncoding];
}


@end

#pragma Old C++ Class

/*
class UIC {
public:
    UIC() {
        start_listener();
    }
private:
    void logout() {
        this->isLoggedIn = false;
        this->delayQuest = false;
        //UserDefaults.standard.synchronize();
        
    }

    static size_t curl_write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
        ((string*)userp)->append((char*)contents, size * nmemb);
        return size * nmemb;
    }
    
    static void postRequest(string url, NSMutableDictionary* data, bool blocking = false, void* completion = NULL) {
        string url = this->backendRawUrl;
        CURL *curl;
        CURLcode res;
        string readBuffer;
        curl = curl_easy_init();
        if (curl) {
            curl_easy_setopt(curl, CURLOPT_URL, this->toObjCString(url));
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write_callback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
            res = curl_easy_perform(curl);
            curl_easy_cleanup(curl);
            
            string recv = readBuffer;
            if (recv.length() > 0) {
                if (completion != NULL) {
                    completion();
                }
            }
        }
    }
    
    static NSMutableDictionary* toDictionary(string data) {
        NSError *error;
        NSString *payload = toObjCString(data);
        NSMutableDictionary *jsonObj = [NSJSONSerialization JSONObjectWithData:
            [payload dataUsingEncoding:NSUTF8StringEncoding]
            options:0
            error:&error];
        if (error != NULL) {
            // TODO: Log error
        }
        return jsonObj;
    }
};
*/
