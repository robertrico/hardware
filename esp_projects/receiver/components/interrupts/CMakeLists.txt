idf_component_register(SRCS "interrupts.c"
    INCLUDE_DIRS "."
    PRIV_REQUIRES esp_driver_gpio esp_wifi nvs_flash
)
