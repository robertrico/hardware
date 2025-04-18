#pragma once
#include <string>

class OTAManager {
public:
    bool checkForUpdate();
    bool downloadAndWrite();
    bool switchToB(const char* version);
    bool checkBootFlag(char* out_version);
    bool clearBootFlag();
    void jumpToB();
};

struct BootFlag {
    char magic[4];
    char version[8];
};