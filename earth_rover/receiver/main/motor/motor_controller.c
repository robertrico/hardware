#include "motor_controller.h"
#include "esp_log.h"
#include "esp_timer.h"

static const char* TAG = "MOTOR_CTRL";

/**
 * @brief Get current time in milliseconds
 */
static uint32_t get_time_ms(void) {
    return (uint32_t)(esp_timer_get_time() / 1000);
}

/**
 * @brief Change controller state and update statistics
 */
static void set_state(motor_controller_t* controller, motor_state_t new_state) {
    if (controller->state != new_state) {
        ESP_LOGI(TAG, "State change: %d -> %d", controller->state, new_state);
        controller->state = new_state;
        controller->stats.state_changes++;
    }
}

esp_err_t motor_controller_init(motor_controller_t* controller, const motor_controller_config_t* config) {
    if (!controller || !config || !config->driver || !config->arcade) {
        ESP_LOGE(TAG, "Invalid configuration");
        return ESP_ERR_INVALID_ARG;
    }
    
    ESP_LOGI(TAG, "Initializing motor controller");
    
    // Copy configuration
    controller->config = *config;
    
    // Set default values if not specified
    if (controller->config.update_period_ms == 0) {
        controller->config.update_period_ms = 20;  // 50Hz default
    }
    if (controller->config.safety_timeout_ms == 0) {
        controller->config.safety_timeout_ms = 500;  // 500ms default
    }
    
    // Initialize state
    controller->state = MOTOR_STATE_DISABLED;
    controller->last_update_time = get_time_ms();
    controller->initialized = 1;
    
    // Clear statistics
    controller->stats.updates_received = 0;
    controller->stats.state_changes = 0;
    controller->stats.error_count = 0;
    controller->stats.last_left_speed = 0;
    controller->stats.last_right_speed = 0;
    
    ESP_LOGI(TAG, "Motor controller initialized (update: %dms, timeout: %dms)",
             controller->config.update_period_ms, controller->config.safety_timeout_ms);
    
    return ESP_OK;
}

esp_err_t motor_controller_update(motor_controller_t* controller, uint16_t x_input, uint16_t y_input) {
    if (!controller || !controller->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    uint32_t now = get_time_ms();
    
    // Check update rate limiting
    if ((now - controller->last_update_time) < controller->config.update_period_ms) {
        return ESP_OK;  // Skip this update
    }
    
    // Update timestamp
    controller->last_update_time = now;
    controller->stats.updates_received++;
    
    // Skip if disabled
    if (controller->state == MOTOR_STATE_DISABLED) {
        return ESP_OK;
    }
    
    // Calculate motor speeds using arcade drive
    const arcade_output_t* output = arcade_drive_calculate(controller->config.arcade, x_input, y_input);
    
    // Update statistics
    controller->stats.last_left_speed = output->left_speed;
    controller->stats.last_right_speed = output->right_speed;
    
    // Apply to motors
    esp_err_t ret = tb6612fng_set_motors(controller->config.driver, 
                                         output->left_speed, 
                                         output->right_speed);
    
    if (ret != ESP_OK) {
        controller->stats.error_count++;
        set_state(controller, MOTOR_STATE_ERROR);
        ESP_LOGE(TAG, "Failed to set motor speeds: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Update state based on output
    if (output->enabled) {
        set_state(controller, MOTOR_STATE_RUNNING);
    } else {
        set_state(controller, MOTOR_STATE_IDLE);
    }
    
    // Log periodically for debugging
    if (controller->stats.updates_received % 50 == 0) {
        ESP_LOGI(TAG, "Update %lu: L=%d R=%d (X=%d Y=%d)", 
                controller->stats.updates_received,
                output->left_speed, output->right_speed,
                x_input, y_input);
    }
    
    return ESP_OK;
}

esp_err_t motor_controller_enable(motor_controller_t* controller) {
    if (!controller || !controller->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    ESP_LOGI(TAG, "Enabling motor controller");
    
    // Enable the motor driver
    esp_err_t ret = tb6612fng_enable(controller->config.driver, 1);
    if (ret != ESP_OK) {
        controller->stats.error_count++;
        return ret;
    }
    
    set_state(controller, MOTOR_STATE_IDLE);
    controller->last_update_time = get_time_ms();
    
    return ESP_OK;
}

esp_err_t motor_controller_disable(motor_controller_t* controller) {
    if (!controller || !controller->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    ESP_LOGI(TAG, "Disabling motor controller");
    
    // Stop motors first
    tb6612fng_stop(controller->config.driver);
    
    // Disable the motor driver
    esp_err_t ret = tb6612fng_enable(controller->config.driver, 0);
    if (ret != ESP_OK) {
        controller->stats.error_count++;
        return ret;
    }
    
    set_state(controller, MOTOR_STATE_DISABLED);
    
    return ESP_OK;
}

esp_err_t motor_controller_emergency_stop(motor_controller_t* controller) {
    if (!controller || !controller->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    ESP_LOGW(TAG, "EMERGENCY STOP");
    
    // Immediately brake motors
    esp_err_t ret = tb6612fng_brake(controller->config.driver);
    if (ret != ESP_OK) {
        controller->stats.error_count++;
    }
    
    set_state(controller, MOTOR_STATE_BRAKING);
    
    return ret;
}

esp_err_t motor_controller_check_safety(motor_controller_t* controller) {
    if (!controller || !controller->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    
    // Skip if already disabled
    if (controller->state == MOTOR_STATE_DISABLED) {
        return ESP_OK;
    }
    
    uint32_t now = get_time_ms();
    uint32_t time_since_update = now - controller->last_update_time;
    
    // Check for timeout
    if (time_since_update > controller->config.safety_timeout_ms) {
        ESP_LOGW(TAG, "Safety timeout (%lu ms since last update)", time_since_update);
        return motor_controller_emergency_stop(controller);
    }
    
    return ESP_OK;
}

motor_state_t motor_controller_get_state(const motor_controller_t* controller) {
    if (!controller || !controller->initialized) {
        return MOTOR_STATE_ERROR;
    }
    return controller->state;
}

const motor_stats_t* motor_controller_get_stats(const motor_controller_t* controller) {
    if (!controller || !controller->initialized) {
        return NULL;
    }
    return &controller->stats;
}