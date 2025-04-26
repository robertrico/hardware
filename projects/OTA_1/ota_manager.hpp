#pragma once
#include <string>
#include "flash_manager.hpp"
#include "pico/cyw43_arch.h"
#include "lwip/tcp.h"
#include "lwip/apps/http_client.h"
#include "lwip/dns.h"
#include "lwip/ip_addr.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
#include "version.h"
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