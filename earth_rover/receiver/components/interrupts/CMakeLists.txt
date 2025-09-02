idf_component_register(SRCS "interrupts.c"
    INCLUDE_DIRS "../../Include"
    PRIV_REQUIRES driver esp_wifi nvs_flash freertos esp_timer esp_system)
