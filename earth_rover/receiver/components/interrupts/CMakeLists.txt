idf_component_register(SRCS "interrupts.c"
    INCLUDE_DIRS "."
    PRIV_REQUIRES esp_driver_spi esp_driver_gpio esp_timer esp_wifi nvs_flash)
