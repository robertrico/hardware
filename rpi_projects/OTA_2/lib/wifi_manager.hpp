#pragma once
#include "pico/stdlib.h"
#include "lwip/netif.h"
#include "lwip/dns.h"
#include "lwip/dhcp.h"
#include "lwip/tcp.h"
#include "lwip/pbuf.h"
#include "lwip/ip_addr.h"
#include "pico/cyw43_arch.h"
#include <cstring>

class WiFiManager {
public:
    WiFiManager();
    static void init();
    static bool connect();
    static bool testConnectivity();
};
