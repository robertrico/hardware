#pragma once
#include <string>

class OTAManager {
public:
    bool checkForUpdate();
    bool downloadAndWrite(const std::string& url);
    bool switchToB();
    void rebootToB();
};
