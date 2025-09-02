idf_component_register(SRCS "main.c"
                            "motor/arcade_drive.c"
                            "motor/tb6612fng.c"
                            "motor/motor_controller.c"
    INCLUDE_DIRS "." "../Include" "motor"
    PRIV_REQUIRES driver esp_wifi nvs_flash esp_system esp_timer freertos interrupts
)
