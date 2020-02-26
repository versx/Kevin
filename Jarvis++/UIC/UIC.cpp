//
//  UIC.cpp
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#include "UIC.hpp"
#include "JSON.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string>

//#include "sstream.h"
//#include "vector.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>

#include <ctime>
#include <math.h>
#include <curl/curl.h>

using namespace std;

// TODO: Remote config

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
    
    // TODO: Properties
    //int currentFriend
    bool shouldExit;
    string username;
    string password;
    bool newLogIn;
    bool isLoggedIn;
    bool newCreated;
    bool needsLogout;
    int minLevel = 0;
    int maxLevel = 29;
    double deviceMultiplier__hgj = 5.0; // 5S/6/6+ 45 else 5.0

    void start_listener() {
        int sockfd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
        struct sockaddr_in servaddr;
        pthread_t thread;
        if (sockfd < 0) {
            perror("socket() error");
            exit(EXIT_FAILURE);
        }
        
        servaddr.sin_family = AF_INET;
        servaddr.sin_port = htons(8080);
        servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
        
        if (bind(sockfd, (struct sockaddr *)&servaddr, sizeof(servaddr)) < 0) {
            perror("bind() error");
            exit(EXIT_FAILURE);
        }
        
        if (listen(sockfd, 1000) < 0) {
            perror("listen() error");
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
                perror("accept() error");
                exit(EXIT_FAILURE);
            }
            
            inet_ntop(clieaddr.ss_family, (void *)&((struct sockaddr_in *)&clieaddr)->sin_addr, s, sizeof(s));
            printf("accept() %s\n", s);
            
            int *pcliefd = new int;
            *pcliefd = cliefd;
            if (pcliefd) { //true
                if (pthread_create(&thread, 0, handle_request, pcliefd) < 0) {
                    perror("pthread_create()");
                }
            } else {
                handle_request(pcliefd);
            }
        }
    }
    
    void logout() {
        this->isLoggedIn = false;
        this->delayQuest = false;
        //UserDefaults.standard.synchronize();
        
    }
    
    static void *handle_request(void *pcliefd) {
        int cliefd = *(int*)pcliefd;
        //delete (int *)pcliefd;
        
        ssize_t n;
        char buffer[255];
        const char *response;
        
        n = recv(cliefd, buffer, sizeof(buffer), 0);
        if (n < 0) {
            perror("recv() error");
            return 0;
        }
        
        buffer[n] = 0;
        printf("recv() %s\n", buffer);
        
        string s(buffer), token;
        /*
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
                    response = handle_data(s);
                    break;
                case "/loc":
                    response = handle_location(s);
                    break;
            }
        }
        */
        
        n = write(cliefd, response, strlen(response));
        if (n < 0) {
            perror("write() error");
            return 0;
        }
        
        close(cliefd);
        return 0;
    }
    
    string handle_location(string data) {
        string response = response_200;
        return response;
    }

    string handle_data(string data) {
        lastUpdate = time(0);
        //self.lock.lock();
        float currentLocation[2] = { this->currentLocation[0], this->currentLocation[1] };
        float targetMaxDistance = this->targetMaxDistance;
        string pokemonEncounterId = this->pokemonEncounterId;
        //self.lock.unlock();
        
        JSONObject *jsonObj = NULL;
        try {
            JSONValue jsonValue = string_to_json(data);
            jsonObj = jsonValue->AsObject();
        } catch (exception &ex) {
            return response_400;
        }
        if (jsonObj == NULL) {
            return response_200;
        }
        if (sizeof(currentLocation) == 0) {
            return response_200;
        }
        
        jsonObj["lat_target"] = currentLocation[0];
        jsonObj["lon_target"] = currentLocation[1];
        jsonObj["target_max_distance"] = targetMaxDistance;
        jsonObj["username"] = this->username;
        jsonObj["pokemon_encounter_id"] = pokemonEncounterId;
        jsonObj["uuid"] = this->uuid;
        jsonObj["ptcToken"] = this->ptcToken__hgj;
        
        string url = this->backendRawUrl;
        CURL *curl;
        CURLcode res;
        string readBuffer;
        curl = curl_easy_init();
        if (curl) {
            curl_easy_setopt(curl, CURLOPT_URL, url);
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write_callback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
            res = curl_easy_perform(curl);
            curl_easy_cleanup(curl);
            
            string recv = readBuffer;
            if (recv.length() > 0) {
                JSONObject result = string_to_json(recv);
                JSONObject data = result["data"];
                bool inArea = data["in_area"];
                int level = data["level"] ?? 0;
                int nearby = data["nearby"] ?? 0;
                int wild = data["wild"] ?? 0;
                int quests = data["quests"] ?? 0;
                int encounters = data["encounters"] ?? 0;
                float pokemonLat = data["pokemon_lat"] ?? 0.0;
                float pokemonLon = data["pokemon_lon"] ?? 0.0;
                string pokemonEncounterIdResult = data["pokemon_encounter_id"];
                float targetLat = data["target_lat"] ?? 0.0;
                float targetLon = data["target_lon"] ?? 0.0;
                bool onlyEmptyGmos = data["only_empty_gmos"] ?? true;
                bool onlyInvalidGmos = data["only_invalid_gmos"] ?? false;
                bool containsGmo = data["contains_gmos"] ?? true;
                
                this->level = level;
                string toPrint;
                
                //self.lock.lock();
                float diffLat = fabs((this->currentLocation[0] ?? 0) - targetLat);
                float diffLon = fabs((this->currentLocation[1] ?? 0) - targetLon);
                
                // TODO: MIZU tut stuff
                
                if (onlyInvalidGmos) {
                    this->waitForData = false;
                    toPrint = "[UIC] Got GMO but it was malformed. Skipping.";
                } else if (containsGmo) {
                    if (inArea && diffLat < 0.0001 && diffLon < 0.0001) {
                        this->emptyGmoCount = 0;
                        if (this->pokemonEncounter != NULL) {
                            if (nearby + wild > 0) {
                                if (pokemonLat != 0 && pokemonLon != 0 && this->pokemonEncounter == pokemonEncounter) {
                                    this->waitRequiresPokemon = false;
                                    int oldLocation[2] = { this->currentLocation[0], this->currentLocation[1] };
                                    this->currentLocation = { pokemonLat, pokemonLon };
                                    int newLocation[2] = { this->currentLocation[0], this->currentLocation[1] };
                                    this->encounterDistance = 0.01; // TODO: newLocation.distance(oldLocation);
                                    this->pokemonEncounterId = NULL;
                                    this->waitFordata = false;
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
                printf(toPrint);
            }
        }
        
        string response = response_200 + jsonObj->AsString();
        return response;
    }
    
    static size_t curl_write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
        ((string*)userp)->append((char*)contents, size * nmemb);
        return size * nmemb;
    }
    
    JSONValue string_to_json(string data) {
        /*
        stringstream sstr(data);
        Json::Value json;
        sstr >> json;
        sstr.close();
        */

        JSONValue *json = JSON::Parse(data);
        if (json == NULL) {
            perror("Failed to parse string to JSONValue");
            return null;
        }
        return json;//->AsObject();
        /*
        sstr >> json;
        string errors;
        bool parsingSuccessful = reader->parse(
            data.c_str(),
            data.c_str(),
            &json,
            &errors
        );
        delete reader;
        
        if (!parsingSuccessful) {
            perror("Failed to parse json, errors:" + errors + "\n");
            return NULL;
        }
        
        json.get("type", "DefaultValue").asString();
        return json;
        */
    }
};
