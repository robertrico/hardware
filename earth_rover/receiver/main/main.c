#include "include.h"
#include "interrupts.h"
#include "motor_controller.h"
#include "arcade_drive.h"
#include "tb6612fng.h"

/**
 * @brief Initializes Wi-Fi in station mode and sets the Wi-Fi channel for ESP-NOW communication.
 *
 * This function performs the following steps:
 * - Initializes NVS flash storage.
 * - Initializes the TCP/IP network interface.
 * - Creates the default event loop.
 * - Initializes the Wi-Fi driver with default configuration.
 * - Sets the Wi-Fi mode to station (STA).
 * - Starts the Wi-Fi driver.
 * - Sets the Wi-Fi channel to the value defined by ESPNOW_CHANNEL with no secondary channel.
 *
 * All steps use ESP_ERROR_CHECK to ensure proper error handling.
 */

static void vWifiInit(void) {
    ESP_ERROR_CHECK(nvs_flash_init());
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_channel(ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE));
}

/**
 * @brief Initializes ESP-NOW and registers the receive callback.
 *
 * This function performs the following steps:
 * - Initializes the ESP-NOW protocol stack.
 * - Registers the vButtonReceive function as the callback for receiving ESP-NOW data.
 *
 * Both steps use ESP_ERROR_CHECK to ensure proper error handling.
 */
static void vESPNowInit(void) {
    ESP_ERROR_CHECK(esp_now_init());
    ESP_ERROR_CHECK(esp_now_register_recv_cb(vButtonReceive));
}

#define EVENT_QUEUE_LENGTH 16
#define EVENT_ITEM_SIZE    16

// Pin definitions for TB6612FNG on ESP32-C3
#define MOTOR_PWMA_PIN   GPIO_NUM_10  // Motor A PWM
#define MOTOR_AIN1_PIN   GPIO_NUM_4   // Motor A direction 1
#define MOTOR_AIN2_PIN   GPIO_NUM_5   // Motor A direction 2
#define MOTOR_PWMB_PIN   GPIO_NUM_9   // Motor B PWM
#define MOTOR_BIN1_PIN   GPIO_NUM_6   // Motor B direction 1
#define MOTOR_BIN2_PIN   GPIO_NUM_7   // Motor B direction 2
#define MOTOR_STBY_PIN   GPIO_NUM_8   // Standby (active high)

// Joystick calibration - ADJUST THESE FOR YOUR JOYSTICK
#define JOYSTICK_CENTER_X  2220   // Measured center position for X-axis
#define JOYSTICK_CENTER_Y  2195   // Measured center position for Y-axis
#define JOYSTICK_DEADBAND_X 225   // Deadband radius for X-axis (reduced by 10% for more responsive throttle)
#define JOYSTICK_DEADBAND_Y 225   // Deadband radius for Y-axis (reduced by 10% for more responsive steering)
#define JOYSTICK_MIN_SPEED  100   // Minimum motor speed (0-1000) to overcome friction

QueueHandle_t rdySem = NULL; // This is the only definition

// Global instances
static tb6612fng_t motor_driver;
static arcade_drive_t arcade_drive;
static motor_controller_t motor_controller;

/**
 * @brief Initialize motor hardware
 */
static esp_err_t init_motor_hardware(void) {
    ESP_LOGI("MAIN", "Initializing motor hardware...");
    
    // Configure TB6612FNG driver
    motor_driver.motor_a.in1_pin = MOTOR_AIN1_PIN;
    motor_driver.motor_a.in2_pin = MOTOR_AIN2_PIN;
    motor_driver.motor_a.pwm_pin = MOTOR_PWMA_PIN;
    motor_driver.motor_a.pwm_channel = LEDC_CHANNEL_0;
    
    motor_driver.motor_b.in1_pin = MOTOR_BIN1_PIN;
    motor_driver.motor_b.in2_pin = MOTOR_BIN2_PIN;
    motor_driver.motor_b.pwm_pin = MOTOR_PWMB_PIN;
    motor_driver.motor_b.pwm_channel = LEDC_CHANNEL_1;
    
    motor_driver.standby_pin = MOTOR_STBY_PIN;
    motor_driver.pwm_frequency = 1000;  // 1kHz PWM
    motor_driver.pwm_resolution = LEDC_TIMER_13_BIT;
    motor_driver.max_duty = 8191;  // 2^13 - 1
    
    // Initialize motor driver
    esp_err_t ret = tb6612fng_init(&motor_driver);
    if (ret != ESP_OK) {
        ESP_LOGE("MAIN", "Failed to initialize TB6612FNG: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Initialize arcade drive calculator with custom calibration
    arcade_drive_init(&arcade_drive);
    
    // Configure joystick with measured values
    joystick_config_t joystick_cfg = {
        .center_x = JOYSTICK_CENTER_X,
        .center_y = JOYSTICK_CENTER_Y,
        .deadband_x = JOYSTICK_DEADBAND_X,
        .deadband_y = JOYSTICK_DEADBAND_Y,
        .max_value = 4095,
        .max_throttle_range = 1720,
        .max_steering_range = 1900
    };
    arcade_drive_configure(&arcade_drive, &joystick_cfg);
    
    arcade_drive_set_steering_reduction(&arcade_drive, 30);  // 30% steering influence
    arcade_drive_set_min_speed(&arcade_drive, JOYSTICK_MIN_SPEED);  // Minimum speed to prevent stalling
    
    ESP_LOGI("MAIN", "Joystick config: Center(%d,%d) Deadband(%d,%d) MinSpeed(%d)",
             JOYSTICK_CENTER_X, JOYSTICK_CENTER_Y, 
             JOYSTICK_DEADBAND_X, JOYSTICK_DEADBAND_Y, 
             JOYSTICK_MIN_SPEED);
    
    // Initialize motor controller
    motor_controller_config_t motor_config = {
        .driver = &motor_driver,
        .arcade = &arcade_drive,
        .update_period_ms = 20,    // 50Hz update rate
        .safety_timeout_ms = 125   // Stop if no data for 125ms
    };
    
    ret = motor_controller_init(&motor_controller, &motor_config);
    if (ret != ESP_OK) {
        ESP_LOGE("MAIN", "Failed to initialize motor controller: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Enable motor controller
    ret = motor_controller_enable(&motor_controller);
    if (ret != ESP_OK) {
        ESP_LOGE("MAIN", "Failed to enable motor controller: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ESP_LOGI("MAIN", "Motor hardware initialized successfully");
    return ESP_OK;
}

void app_main(void) {
    // Early boot message - this should appear immediately
    printf("\n\n=== ESP32-C3 Receiver Starting ===\n");
    printf("Firmware built: %s %s\n", __DATE__, __TIME__);
    printf("Initializing system...\n\n");
    
    // Small delay to ensure UART is ready
    vTaskDelay(pdMS_TO_TICKS(100));
    
    ESP_LOGI("BOOT", "Creating message queue...");
    rdySem = xQueueCreate(EVENT_QUEUE_LENGTH, EVENT_ITEM_SIZE);
    if (rdySem == NULL) {
        ESP_LOGE("BOOT", "Failed to create queue!");
        return;
    }
    
    ESP_LOGI("BOOT", "Initializing WiFi...");
    vWifiInit();
    
    ESP_LOGI("BOOT", "Initializing ESP-NOW...");
    vESPNowInit();

    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);

    // Configure LED for visual feedback
    gpio_config_t io_conf;
    io_conf.pin_bit_mask = 1ULL << LED_GPIO;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
    io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    io_conf.intr_type = GPIO_INTR_DISABLE;

    gpio_config(&io_conf);

    // Initialize motor hardware
    esp_err_t ret = init_motor_hardware();
    if (ret != ESP_OK) {
        ESP_LOGE("MAIN", "Motor initialization failed, running in monitor-only mode");
    }
    
    printf("\n=== Receiver Ready ===\n");
    printf("MAC Address: %02X:%02X:%02X:%02X:%02X:%02X\n", 
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    printf("ESP-NOW Channel: %d\n", ESPNOW_CHANNEL);
    printf("Motor Control: %s\n", (ret == ESP_OK) ? "ENABLED" : "DISABLED");
    printf("Waiting for joystick data...\n\n");
    
    ESP_LOGI("MAIN", "System initialization complete");

    uint32_t receive_count = 0;
    uint32_t last_heartbeat = 0;
    uint32_t last_safety_check = 0;
    
    ESP_LOGI("MAIN", "Entering main loop...");
    
    while(1) {
        uint8_t payload[16];
        
        // Use a timeout so we can perform safety checks
        if (xQueueReceive(rdySem, payload, pdMS_TO_TICKS(100))) {
            receive_count++;
            
            // Extract joystick values
            uint16_t bx = payload[0] | (payload[1] << 8);
            uint16_t by = payload[2] | (payload[3] << 8);
            
            // Update motor controller
            if (motor_controller.initialized) {
                esp_err_t err = motor_controller_update(&motor_controller, bx, by);
                if (err != ESP_OK) {
                    ESP_LOGE("MAIN", "Motor update failed: %s", esp_err_to_name(err));
                }
            }
            
            // Output values to console periodically with detailed debug
            if (receive_count % 10 == 0) {
                const motor_stats_t* stats = motor_controller_get_stats(&motor_controller);
                int16_t left_speed = stats ? stats->last_left_speed : 0;
                int16_t right_speed = stats ? stats->last_right_speed : 0;
                
                // Calculate distances from center
                int16_t x_offset = (int)bx - JOYSTICK_CENTER_X;
                int16_t y_offset = (int)by - JOYSTICK_CENTER_Y;
                
                // Show when in deadband
                uint8_t x_in_deadband = (abs(x_offset) < JOYSTICK_DEADBAND_X);
                uint8_t y_in_deadband = (abs(y_offset) < JOYSTICK_DEADBAND_Y);
                uint8_t in_deadband = x_in_deadband && y_in_deadband;
                
                printf("[%lu] Joy(%d,%d) Off(%+d,%+d) | M(L:%+4d R:%+4d) | %s%s%s\n", 
                       receive_count, bx, by,
                       x_offset, y_offset,
                       left_speed, right_speed,
                       in_deadband ? "DEADBAND" : "ACTIVE",
                       (!in_deadband && left_speed == 0 && right_speed == 0) ? " [MIN_SPEED]" : "",
                       (left_speed == 0 && right_speed == 0) ? " PWM=0" : "");
            }
            
            // Toggle LED to show activity
            gpio_set_level(LED_GPIO, receive_count % 2);
        }
        
        // Periodic safety check
        uint32_t now = xTaskGetTickCount();
        if ((now - last_safety_check) > pdMS_TO_TICKS(100)) {
            last_safety_check = now;
            
            if (motor_controller.initialized) {
                motor_controller_check_safety(&motor_controller);
            }
            
            // Heartbeat every 5 seconds
            if ((now - last_heartbeat) > pdMS_TO_TICKS(5000)) {
                last_heartbeat = now;
                const motor_stats_t* stats = motor_controller_get_stats(&motor_controller);
                printf("[Heartbeat] Packets: %lu | Updates: %lu | Errors: %lu\n",
                       receive_count,
                       stats ? stats->updates_received : 0,
                       stats ? stats->error_count : 0);
            }
        }
    } 
}
