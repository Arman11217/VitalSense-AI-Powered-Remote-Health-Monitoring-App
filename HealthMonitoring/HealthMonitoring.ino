/**
 * ============================================================================
 *  File:        HealthMonitoring.ino
 *  Board:       ESP32 ESP-32S NodeMCU (30 Pin)
 *  Phase:       2 - Sensors + WiFi + Firebase Data Streaming
 *
 *  All hardware configuration lives in config.h.
 *  All sensors are encapsulated as C++ classes.
 *  Main loop is a pure scheduler - no delay() blocking.
 * ============================================================================
 */
#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include "config.h"
#include "max30102.h"
#include "ecg.h"
#include "temperature.h"
#include "buzzer.h"
#include "display.h"

#if FEATURE_WIFI
  #include "MyWiFiManager.h"
#endif
#if FEATURE_FIREBASE
  #include "firebase.h"
#endif

/* ============================================================================
 *                              GLOBAL OBJECTS
 * ============================================================================ */
Max30102    g_max30102;
Ecg         g_ecg;
Temperature g_temp;
Buzzer      g_buzzer;
Display     g_display;

#if FEATURE_WIFI
WiFiManager g_wifi;
#endif
#if FEATURE_FIREBASE
FirebasePublisher g_firebase;
#endif

/* ============================================================================
 *                              TIMING VARIABLES
 * ============================================================================ */
uint32_t g_lastEcgMs             = 0;
uint32_t g_lastTempMs            = 0;
uint32_t g_lastBuzzerMs          = 0;
uint32_t g_lastSerialMs          = 0;

#if FEATURE_FIREBASE
uint32_t g_lastFirebaseLatestMs  = 0;
uint32_t g_lastFirebaseHistoryMs = 0;
uint32_t g_lastWifiWarnMs        = 0;
#endif

/* ============================================================================
 *                                  SETUP
 * ============================================================================ */
void setup() {
    Serial.begin(SERIAL_BAUD_RATE);
    delay(100);

    // Initialize I2C Master Bus explicitly with config pins
#if defined(I2C_SDA_PIN) && defined(I2C_SCL_PIN)
    Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN, 400000UL);
#else
    Wire.begin();
    Wire.setClock(400000UL);
#endif

    // Print header banner
    g_display.printBanner();

    // Initialize physical sensors and modules
    if (!g_max30102.begin()) {
        Serial.println("[WARN] MAX30102 init failed or not detected!");
    } else {
        Serial.println("[OK] MAX30102 initialised.");
    }

    g_ecg.begin();
    g_temp.begin();
    g_buzzer.begin();

    Serial.println("[OK] Sensors initialised.");

#if FEATURE_WIFI
    Serial.println("[WiFi] Starting Connection Process...");
    g_wifi.begin();
#endif

#if FEATURE_FIREBASE
    g_firebase.setDeviceId(DEVICE_ID);
    Serial.print("[FB] Target DB Host: ");
    Serial.println(FIREBASE_DB_HOST);
#endif

    Serial.println("[SYSTEM] Setup completed. Main scheduler loop starting...\n");
}

/* ============================================================================
 *                                  LOOP
 * ============================================================================ */
void loop() {
    uint32_t now = millis();

    // ---- WiFi State Machine Processing ----
#if FEATURE_WIFI
    g_wifi.update();
#endif

    // ---- MAX30102 continuous drain (NO TIMER) ----
    // Continuous polling ensures FIFO never overflows and I2C does not lock
    g_max30102.update();

    // ---- ECG sampling: 100 Hz ----
    if (now - g_lastEcgMs >= PERIOD_ECG_MS) {
        g_lastEcgMs = now;
        g_ecg.update();
    }

    // ---- Temperature: 1 Hz ----
    if (now - g_lastTempMs >= PERIOD_TEMP_MS) {
        g_lastTempMs = now;
        g_temp.update();
    }

    // ---- Buzzer non-blocking state machine ----
    if (now - g_lastBuzzerMs >= PERIOD_BUZZER_MS) {
        g_lastBuzzerMs = now;
        g_buzzer.update();
    }

    // ---- Serial dashboard print: 1 Hz ----
    if (now - g_lastSerialMs >= PERIOD_SERIAL_MS) {
        g_lastSerialMs = now;
        g_display.printFrame(g_max30102, g_ecg, g_temp);

#if FEATURE_WIFI
        Serial.print("[WiFi Status] ");
        Serial.println(g_wifi.statusText());
#endif
    }

    // ---- Firebase Publish Logic ----
#if FEATURE_FIREBASE
  #if FEATURE_WIFI
    // Only push to Firebase when WiFi is connected
    if (g_wifi.isConnected()) {
  #endif

        // 1. Send /latest node snapshot (1 Hz)
        if (now - g_lastFirebaseLatestMs >= PERIOD_FIREBASE_MS) {
            g_lastFirebaseLatestMs = now;

            SensorSnapshot snap = {
                .max30102    = &g_max30102,
                .ecg         = &g_ecg,
                .temp        = &g_temp,
#if FEATURE_WIFI
                .rssi        = g_wifi.rssi(),
#else
                .rssi        = 0,
#endif
                .timestampMs = now,
            };

            FirebaseStatus res = g_firebase.pushLatest(snap);
            if (res == FirebaseStatus::OK) {
                Serial.println("[FB] Realtime stream: OK");
            } else {
                Serial.print("[FB] Realtime stream error code: ");
                Serial.println((int)res);
            }
        }

        // 2. Append to /history node (Every PERIOD_HISTORY_MS, e.g. 5 sec)
        if (now - g_lastFirebaseHistoryMs >= PERIOD_HISTORY_MS) {
            g_lastFirebaseHistoryMs = now;

            SensorSnapshot snap = {
                .max30102    = &g_max30102,
                .ecg         = &g_ecg,
                .temp        = &g_temp,
#if FEATURE_WIFI
                .rssi        = g_wifi.rssi(),
#else
                .rssi        = 0,
#endif
                .timestampMs = now,
            };

            FirebaseStatus res = g_firebase.pushHistory(snap);
            if (res == FirebaseStatus::OK) {
                Serial.println("[FB] History log appended: OK");
            }
        }

  #if FEATURE_WIFI
    } else {
        // Log warning every 5 seconds if WiFi is not connected
        if (now - g_lastWifiWarnMs >= 5000) {
            g_lastWifiWarnMs = now;
            Serial.println("[FB] Waiting for WiFi connection to stream data...");
        }
    }
  #endif
#endif

    // Yield & delay to keep ESP32 Watchdog Timer (WDT) and FreeRTOS tasks happy
    yield();
    delay(1);
}