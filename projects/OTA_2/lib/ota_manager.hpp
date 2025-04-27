#pragma once
#include <string>
// #include "flash_manager.hpp"
#include "pico/cyw43_arch.h"
#include "lwip/tcp.h"
#include "lwip/apps/http_client.h"
#include "lwip/dns.h"
#include "lwip/ip_addr.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
// #include "version.h"
#include <string>
#include <cstring>
#include <cstdio>
#include "pico/stdlib.h"
#include "hardware/structs/scb.h"
#include "pico/bootrom/sf_table.h"
#include "pico/mem_ops.h"
#include <stddef.h>


class OTAManager {
public:
    static bool checkForUpdate();
    static bool updateBootConfig(const char* version);
    static bool downloadAndWrite();
    //static bool switchToB(const char* version);
    //static bool checkBootFlag(char* out_version);
    //static bool clearBootFlag();
    //static void jumpToB();
};


