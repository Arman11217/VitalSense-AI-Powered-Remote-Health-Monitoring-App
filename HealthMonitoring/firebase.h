/**
 * ============================================================================
 *  File:        firebase.h
 *  Description: Firebase Realtime Database publisher (REST API).
 *
 *  This driver uses HTTP REST (POST/PATCH) to push JSON to Firebase RTDB.
 *  No external Firebase Arduino library is required -> small footprint.
 *
 *  Dependencies: WiFiManager (must be CONNECTED before push).
 *  Threading   : NOT thread-safe; call from loop() only.
 * ============================================================================
 */

#ifndef FIREBASE_H
#define FIREBASE_H

#include <Arduino.h>
#include <HTTPClient.h>
#include <WiFiClient.h>
#include "config.h"
#include "max30102.h"
#include "ecg.h"
#include "temperature.h"

struct SensorSnapshot {
    const Max30102   *max30102;
    const Ecg        *ecg;
    const Temperature*temp;
    int32_t          rssi;        // dBm
    uint32_t         timestampMs;
};

enum class FirebaseStatus : uint8_t {
    OK                  = 0,
    WIFI_NOT_CONNECTED  = 1,
    HTTP_ERROR          = 2,
    BUILD_ERROR         = 3,
};

class FirebasePublisher {
public:
    FirebasePublisher();

    /** Set the device ID (used in path: devices/<id>/latest). */
    void setDeviceId(const char* id) { _deviceId = id; }

    /** Push the "latest" snapshot (overwrite at devices/<id>/latest). */
    FirebaseStatus pushLatest(const SensorSnapshot &s);

    /** Append a reading to devices/<id>/history. */
    FirebaseStatus pushHistory(const SensorSnapshot &s);

    /** Push an alert entry under /alerts. */
    FirebaseStatus pushAlert(const char* type, const char* detail);

    /** Returns the host (for diagnostics). */
    const char* host() const { return FIREBASE_DB_HOST; }

private:
    const char*      _deviceId = DEVICE_ID;

    /** Build a JSON string for one snapshot. Returns bytes written, or 0 on error. */
    size_t buildSnapshotJson(const SensorSnapshot &s, char *out, size_t outSize);

    /** Internal REST helpers. */
    FirebaseStatus httpRequest(const char* url,
                               const char* method,
                               const char* jsonBody,
                               int *httpCodeOut = nullptr);

    void buildLatestUrl   (char *out, size_t outSize) const;
    void buildHistoryUrl  (char *out, size_t outSize) const;
    void buildAlertUrl    (char *out, size_t outSize) const;
};

#endif // FIREBASE_H
