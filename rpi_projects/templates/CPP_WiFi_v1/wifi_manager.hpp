#pragma once

#include "pico/cyw43_arch.h"
#include "lwip/ip_addr.h"

class WiFiManager {
public:
    WiFiManager();
    bool connect();
    bool testConnectivity();
    void poll();

private:
    void setupGpios();
};
