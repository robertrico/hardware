#pragma once
#include <string>

class OTAManager {
public:
    bool checkForUpdate();
    bool downloadAndWrite();
    bool switchToB();
    void rebootToB();
};
