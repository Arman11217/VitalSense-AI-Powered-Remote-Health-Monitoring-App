/**
 * ============================================================================
 *  File:        config.h
 *  Project:     AI-Powered Remote Health Monitoring and Disease Prediction
 *  Board:       ESP32 ESP-32S NodeMCU (30 Pin)
 *  Framework:   Arduino (ESP32 Core)
 *  Author:      Firmware Team
 *  Description: Central hardware configuration and system-wide constants.
 * ============================================================================
 */

#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

/* ============================================================================
 *                               BOARD IDENTITY
 * ============================================================================ */
constexpr const char* FIRMWARE_NAME      = "HealthMonitoring";
constexpr const char* FIRMWARE_VERSION   = "0.2.0-Phase2";
constexpr const char* DEVICE_MODEL       = "ESP32-NodeMCU-30P";
constexpr const char* DEVICE_ID          = "esp32_001";   // path: devices/<id>/...

/* ============================================================================
 *                            SERIAL MONITOR SETTINGS
 * ============================================================================ */
constexpr uint32_t SERIAL_BAUD_RATE      = 115200;

/* ============================================================================
 *                              I2C BUS (MAX30102)
 * ============================================================================ */
constexpr uint8_t  I2C_SDA_PIN           = 21;
constexpr uint8_t  I2C_SCL_PIN           = 22;
constexpr uint32_t I2C_CLOCK_HZ          = 100000UL;     // 100 kHz
constexpr uint8_t  MAX30102_I2C_ADDR     = 0x57;          // 7-bit address

/* ============================================================================
 *                          MAX30102 SENSOR SETTINGS
 * ============================================================================ */
constexpr uint8_t  MAX30102_SAMPLE_RATE    = 100;         // Hz
constexpr uint8_t  MAX30102_LED_PULSE_WIDTH = 411;         // ADC resolution
constexpr uint32_t MAX30102_RED_LED_CURRENT = 0x3F;       // ~7 mA typical
constexpr uint32_t MAX30102_IR_LED_CURRENT  = 0x3F;

/* ============================================================================
 *                            AD8232 ECG PINS
 * ============================================================================ */
constexpr uint8_t  ECG_OUTPUT_PIN        = 34;           // ADC1_CH6
constexpr uint8_t  ECG_LO_PLUS_PIN       = 26;
constexpr uint8_t  ECG_LO_MINUS_PIN      = 27;

/* ============================================================================
 *                         DIGITAL TEMPERATURE MODULE
 * ============================================================================ */
constexpr uint8_t  TEMP_DIGITAL_PIN      = 4;            // D4
constexpr bool     TEMP_ACTIVE_HIGH      = true;         // HIGH = HOT

/* ============================================================================
 *                              ACTIVE BUZZER
 * ============================================================================ */
constexpr uint8_t  BUZZER_PIN            = 25;
constexpr bool     BUZZER_ACTIVE_HIGH    = true;         // HIGH = ON
constexpr uint16_t EMERGENCY_BEEP_ON_MS  = 250;
constexpr uint16_t EMERGENCY_BEEP_OFF_MS = 250;

/* ============================================================================
 *                          TASK SCHEDULING (millis)
 * ============================================================================ */
constexpr uint32_t PERIOD_MAX30102_MS    = 1000;          // 1 Hz
constexpr uint32_t PERIOD_ECG_MS         = 10;            // 100 Hz
constexpr uint32_t PERIOD_TEMP_MS        = 1000;          // 1 Hz
constexpr uint32_t PERIOD_BUZZER_MS      = 50;            // 20 Hz
constexpr uint32_t PERIOD_SERIAL_MS      = 1000;          // 1 Hz

/* ============================================================================
 *                          HEALTH THRESHOLDS
 * ============================================================================ */
constexpr uint8_t  HR_MIN_BPM            = 50;
constexpr uint8_t  HR_MAX_BPM            = 120;
constexpr uint8_t  SPO2_MIN_PCT          = 92;
constexpr float    TEMP_HOT_THRESHOLD_C  = 38.0f;

/* ============================================================================
 *                             FEATURE FLAGS (Fixed)
 * ----------------------------------------------------------------------------
 *  Using #define instead of constexpr bool so C preprocessor #if directives
 *  can correctly evaluate them (1 = Enabled, 0 = Disabled).
 * ============================================================================ */
#define FEATURE_WIFI          1
#define FEATURE_FIREBASE      1
#define FEATURE_AI_PREDICTION 0
#define FEATURE_FLUTTER_PUSH  0

/* ============================================================================
 *                            FIREBASE SETTINGS
 * ============================================================================ */
constexpr const char* FIREBASE_DB_HOST =
    "ai-health-monitoring-app-default-rtdb.asia-southeast1.firebasedatabase.app";

constexpr uint32_t PERIOD_FIREBASE_MS    = 1000;          // 1 Hz push
constexpr uint32_t PERIOD_HISTORY_MS     = 5000;          // 5s history log

#endif // CONFIG_H