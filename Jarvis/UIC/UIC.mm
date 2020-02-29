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
#include <string>

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIDevice.h>

//#import <GCDAsyncSocket.h> // for TCP

//#include <sstream.h>
//#include <vector.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>

//#include <ctime>
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
static NSString *_modelName = [[UIDevice currentDevice] localizedModel];// TODO: UIDevice.modelName__hgj;
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

// Mizu
/*
string targetFortId;
bool isQuestInit = false;
float lastQuestLocation[2];
float lastLocation[2];
bool gotItems = false;
int noItemsCount = 0;
bool skipSpin = false;
int luckyEggsNum = 0;
time_t lastDeployTime = time(0);
int spins = 401;
bool ultraQuestSpin = false;
*/

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
    NSLog(@"[UIC] Device Model: %@", _modelName);
    NSLog(@"[UIC] Device OS: %@", _osName);
    NSLog(@"[UIC] Device OS Version: %@", _osVersion);
    _port = port;
    //[self start_listener:port];
    start_listener(port);
    return 0;
}
//-(void *)start_listener:(NSNumber *)port
static void* start_listener(NSNumber *port)
{
    NSLog(@"[UIC] start_listener: %@", port);
    _port = port;
    
    int sockfd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    struct sockaddr_in servaddr;
    pthread_t thread;
    if (sockfd < 0) {
        NSLog(@"[UIC] socket() error");
        close(sockfd);
        exit(EXIT_FAILURE);
    }
    
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(8080);
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    
    if (bind(sockfd, (struct sockaddr *)&servaddr, sizeof(servaddr)) < 0) {
        NSLog(@"[UIC] bind() error");
        close(sockfd);
        exit(EXIT_FAILURE);
    }
    
    if (listen(sockfd, 1000) < 0) {
        NSLog(@"[UIC] listen() error");
        close(sockfd);
        exit(EXIT_FAILURE);
    }
    
    struct sockaddr_storage clieaddr;
    int cliefd;
    char s[INET_ADDRSTRLEN];
    socklen_t cliesize;
    
    while (true) {
        cliesize = sizeof(clieaddr);
        cliefd = accept(sockfd, (struct sockaddr *)&clieaddr, &cliesize);
        if (cliefd < 0) {
            NSLog(@"[UIC] accept() error");
            exit(EXIT_FAILURE);
        }
        
        inet_ntop(clieaddr.ss_family, (void *)&((struct sockaddr_in *)&clieaddr)->sin_addr, s, sizeof(s));
        NSLog(@"[UIC] accept() %s\n", s);
        
        int *pcliefd = new int;
        *pcliefd = cliefd;
        if (pcliefd) { //true
            if (pthread_create(&thread, 0, handle_request, pcliefd) < 0) {
                NSLog(@"[UIC] Handling request from %ld with new thread. pthread_create()", (long)pcliefd);
            }
        } else {
            //[self handle_request:pcliefd];
            NSLog(@"[UIC] Handling request from %ld", (long)pcliefd);
            handle_request(pcliefd);
        }
    }
}
/*
- (void)socket:(GCDAsyncSocket *)sender didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // The "sender" parameter is the listenSocket we created.
    // The "newSocket" is a new instance of GCDAsyncSocket.
    // It represents the accepted incoming client connection.

    // Do server stuff with newSocket...
}
- (void)socket:(GCDAsyncSocket *)sender didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == HTTP_HEADER)
    {
        int bodyLength = [self parseHttpHeader:data];
        [socket readDataToLength:bodyLength withTimeout:-1 tag:HTTP_BODY];
    }
    else if (tag == HTTP_BODY)
    {
        // Process response
        [self processHttpBody:data];

        // Read header of next response
        NSData *term = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        [socket readDataToData:term withTimeout:-1 tag:HTTP_HEADER];
    }
}
*/

// TODO: Convert C code to ObjC and make ObjC method.
static void* handle_request(void* pcliefd) {
    NSLog(@"[UIC] handle_request: %ld", (long)pcliefd);
    int cliefd = *(int*)pcliefd;
    //delete (int *)pcliefd;
    
    ssize_t n;
    char buffer[255];
    const char *response = "";
    
    n = recv(cliefd, buffer, sizeof(buffer), 0);
    if (n < 0) {
        NSLog(@"[UIC] recv() error");
        // TODO: close cliefd?
        return 0;
    }
    
    buffer[n] = 0;
    NSLog(@"[UIC] recv() %s\n", buffer);
     
    /*
    string s(buffer), token;
    istringstream ss(s);
    vector<string> token_list;
    for (int i = 0; i < 3 && ss; i++) {
        ss >> token;
        //printf("token %d %s\n", i, token.c_str());
        token_list.push_back(token);
    }
    
    if (token_list.size() == 3
        && (token_list[0] == "GET" || token_list[0] == "POST")
        && token_list[2].substr(0, 4) == "HTTP") {
        switch (token_list[1]) {
            case "/data":
                response = [UIC handle_data: s];
                //response = handle_data(s);
                break;
            case "/loc":
                response = handle_location(s);
                break;
        }
    }
    */
     
    n = write(cliefd, response, strlen(response));
    if (n < 0) {
        NSLog(@"[UIC] write() error");
        // TODO: close cliefd?
        return 0;
    }

    close(cliefd);
    return 0;
}
 
-(NSString *)handle_location:(NSString *) data {
     NSString *response = _response_200;
     return response;
 }
 
-(NSString *)handle_data:(NSString *) data {
    _lastUpdate = [NSDate date];
    //self.lock.lock();
    CLLocation *currentLoc = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(
                                _currentLocation.coordinate.latitude,
                                _currentLocation.coordinate.longitude)
                                  altitude:-1
                        horizontalAccuracy:_baseHorizontalAccuracy
                          verticalAccuracy:_baseVerticalAccuracy
                                 timestamp:[NSDate date]];
    NSNumber *targetMaxDistance = _targetMaxDistance;
    NSString *pokemonEncounterId = _pokemonEncounterId;
    //self.lock.unlock();

    NSMutableDictionary* jsonObj;
    NSError *error;
    try {
        jsonObj = [NSJSONSerialization JSONObjectWithData:
                   [data dataUsingEncoding:NSUTF8StringEncoding]
                   options:0
                   error:&error];
    } catch (exception &ex) {
        return _response_400;
    }
    if (jsonObj == NULL) {
        return _response_200;
    }
    if (_currentLocation == nil) {
        return _response_200;
    }

    jsonObj[@"lat_target"] = @(currentLoc.coordinate.latitude);
    jsonObj[@"lon_target"] = @(currentLoc.coordinate.longitude);
    jsonObj[@"target_max_distance"] = targetMaxDistance;
    jsonObj[@"username"] = _username;
    jsonObj[@"pokemon_encounter_id"] = pokemonEncounterId;
    jsonObj[@"uuid"] = _uuid;
    jsonObj[@"ptcToken"] = _ptcToken__hgj;
     
    /*
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
    NSString *response = [NSString stringWithFormat:@"%@\r\n%@", _response_200, jsonObj];
    return response;
}


@end

/*
class UIC {
public:
    UIC() {
        start_listener();
    }
private:
    string backend = "http://10.0.1.100:9001";
    string backendControllerUrl = backend + "/controler";
    string backendRawUrl = backend + "/raw";
    string localUrl = "http://localhost:8080/loc";
    string uuid = "test"; // TODO: UIDevice.current.name;
    string modelName = "test"; // TODO: UIDevice.modelName__hgj;
    bool started = false;
    float currentLocation[2] = { 0, 0 };
    bool waitRequiresPokemon = false;
    bool waitForData = false;
    //lock = NSLock();
    time_t firstWarningDate; // ctime(time(&0))
    int jitterCorner = 0;
    bool gotQuest = false;
    bool gotIV = false;
    int noQuestCount = 0;
    int noEncounterCount = 0;
    float targetMaxDistance = 250.0;
    int emptyGmoCount = 0;
    string pokemonEncounterId;
    string action;
    float encounterDistance = 0.0;
    float encounterDelay = 0.0;
    void* image; // UIImage
    int level = 0;
    string ptcToken__hgj; // Load from UserDefaults (5750bac0-483c-4131-80fd-6b047b2ca7b4)
    bool menuButton__hgj = false;
    bool menuButton2__hgj = false;
    string neededButton = "";
    bool okButton__hgj = false;
    bool newPlayerButton__hgj = false;
    bool bannedScreen__hgj = false;
    bool invalidScreen__hgj = false;
    //string loggingUrl = "";
    //string loggingPort = 80;
    //string loggingUseTls = true;
    float startupLat = 0.0;
    float startupLon = 0.0;
    float startupLocation[2];
    float lastEncounterLat = 0.0;
    float lastEncounterLon = 0.0;
    time_t lastUpdate = time(0);
    bool delayQuest = false;
    bool gotQuestEarly = false;
    string friendName = "";
    
    // Mizu
    string targetFortId;
    bool isQuestInit = false;
    float lastQuestLocation[2];
    float lastLocation[2];
    bool gotItems = false;
    int noItemsCount = 0;
    bool skipSpin = false;
    int luckyEggsNum = 0;
    time_t lastDeployTime = time(0);
    int spins = 401;
    bool ultraQuestSpin = false;
    
    const char *response_200 = "HTTP/1.1 200 OK\nContent-Type: text/json; charset=utf-8\n\n";
    const char *response_400 = "HTTP/1.1 400 Bad Request\nContent-Type: text/json; charset=utf-8\n\n";
    const char *response_404 = "HTTP/1.1 404 Not Found\nContent-Type: text/json; charset=utf-8\n\n";

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
    
    static NSString* toObjCString(string value) {
        return [NSString stringWithCString:value.c_str() encoding:[NSString NSUTF8Encoding]];
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
