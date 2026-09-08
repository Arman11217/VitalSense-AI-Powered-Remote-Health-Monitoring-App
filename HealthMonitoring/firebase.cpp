
/**
 * ============================================================================
 *  File:        firebase.cpp
 *
 *  REST URLs built from FIREBASE_DB_HOST:
 *     PUT  /devices/<id>/latest.json
 *     POST /devices/<id>/history.json      (returns push key, e.g. -NxYz...)
 *     POST /alerts.json
 *
 *  Example:
 *     https://ai-health-monitoring-app-default-rtdb.asia-southeast1.firebasedatabase.app
 *     /devices/esp32_001/latest.json
 * ============================================================================
 */

#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include "firebase.h"
#include "config.h"

#if FEATURE_WIFI
  #include "MyWiFiManager.h"
  #include <WiFiClientSecure.h>
#endif
#include <HTTPClient.h>

#if FEATURE_WIFI
/* External reference to the WiFi manager so we can guard HTTP calls. */
extern WiFiManager g_wifi;
#endif

FirebasePublisher::FirebasePublisher() {}

/* ----------------------------------------------------------------------------
 *                         URL BUILDERS
 * -------------------------------------------------------------------------- */
void FirebasePublisher::buildLatestUrl(char *out, size_t outSize) const {
    snprintf(out, outSize,
             "https://%s/devices/%s/latest.json",
             FIREBASE_DB_HOST, _deviceId);
}

void FirebasePublisher::buildHistoryUrl(char *out, size_t outSize) const {
    snprintf(out, outSize,
             "https://%s/devices/%s/history.json",
             FIREBASE_DB_HOST, _deviceId);
}

void FirebasePublisher::buildAlertUrl(char *out, size_t outSize) const {
    snprintf(out, outSize,
             "https://%s/alerts.json", FIREBASE_DB_HOST);
}

/* ----------------------------------------------------------------------------
 *                         JSON SNAPSHOT BUILDER
 * -------------------------------------------------------------------------- */
size_t FirebasePublisher::buildSnapshotJson(const SensorSnapshot &s,
                                            char *out, size_t outSize) {
    if (!s.max30102 || !s.ecg || !s.temp) return 0;

    const char *signalText =
        (s.max30102->signalQuality() == SignalQuality::GOOD) ? "GOOD" :
        (s.max30102->signalQuality() == SignalQuality::POOR) ? "POOR" : "NO_FINGER";

    int n = snprintf(out, outSize,
        "{"
            "\"timestamp_ms\":%lu,"
            "\"heart_rate_bpm\":%u,"
            "\"spo2_pct\":%u,"
            "\"ir_value\":%lu,"
            "\"red_value\":%lu,"
            "\"finger_detected\":%s,"
            "\"signal_quality\":\"%s\","
            "\"ecg_adc\":%u,"
            "\"lead_connected\":%s,"
            "\"temperature\":\"%s\","
            "\"wifi_rssi\":%ld"
        "}",
        (unsigned long)s.timestampMs,
        s.max30102->heartRate(),
        s.max30102->spo2(),
        (unsigned long)s.max30102->irValue(),
        (unsigned long)s.max30102->redValue(),
        (s.max30102->fingerStatus() == FingerStatus::PRESENT) ? "true" : "false",
        signalText,
        s.ecg->adcValue(),
        s.ecg->leadConnected() ? "true" : "false",
        s.temp->statusText(),
        (long)s.rssi);

    return (n > 0 && (size_t)n < outSize) ? (size_t)n : 0;
}

/* ----------------------------------------------------------------------------
 *                         REST HELPERS
 * -------------------------------------------------------------------------- */
FirebaseStatus FirebasePublisher::httpRequest(const char* url,
                                              const char* method,
                                              const char* jsonBody,
                                              int *httpCodeOut) {
#if FEATURE_WIFI
    if (!g_wifi.isConnected()) {
        return FirebaseStatus::WIFI_NOT_CONNECTED;
    }
#endif

#if FEATURE_WIFI
    WiFiClientSecure client;     // Firebase requires TLS
    client.setInsecure();        // skip CA bundle (small memory, OK for demos)
#else
    WiFiClient client;           // no TLS - only for LAN / dev tests
#endif
    HTTPClient http;
    http.begin(client, url);
    http.setReuse(false);
    http.addHeader("Content-Type", "application/json");

    int code;
    if (strcmp(method, "PUT") == 0) {
        code = http.PUT(jsonBody);
    } else if (strcmp(method, "POST") == 0) {
        code = http.POST(jsonBody);
    } else if (strcmp(method, "PATCH") == 0) {
        code = http.PATCH(jsonBody);
    } else {
        http.end();
        return FirebaseStatus::BUILD_ERROR;
    }

    if (httpCodeOut) *httpCodeOut = code;
    http.end();
    return (code >= 200 && code < 300) ? FirebaseStatus::OK
                                       : FirebaseStatus::HTTP_ERROR;
}

/* ----------------------------------------------------------------------------
 *                         PUBLIC PUBLISHERS
 * -------------------------------------------------------------------------- */
FirebaseStatus FirebasePublisher::pushLatest(const SensorSnapshot &s) {
    char url[200];
    char body[400];
    buildLatestUrl(url, sizeof(url));
    if (buildSnapshotJson(s, body, sizeof(body)) == 0) {
        return FirebaseStatus::BUILD_ERROR;
    }
    int code = 0;
    FirebaseStatus r = httpRequest(url, "PUT", body, &code);
    if (r != FirebaseStatus::OK) {
        Serial.print("[FB] pushLatest FAILED code=");
        Serial.println(code);
    }
    return r;
}

FirebaseStatus FirebasePublisher::pushHistory(const SensorSnapshot &s) {
    char url[200];
    char body[400];
    buildHistoryUrl(url, sizeof(url));
    if (buildSnapshotJson(s, body, sizeof(body)) == 0) {
        return FirebaseStatus::BUILD_ERROR;
    }
    return httpRequest(url, "POST", body);
}

FirebaseStatus FirebasePublisher::pushAlert(const char* type, const char* detail) {
    char url[200];
    char body[256];
    buildAlertUrl(url, sizeof(url));
    snprintf(body, sizeof(body),
        "{\"device\":\"%s\",\"timestamp_ms\":%lu,\"type\":\"%s\",\"detail\":\"%s\"}",
        _deviceId, (unsigned long)millis(), type, detail);
    return httpRequest(url, "POST", body);
}
