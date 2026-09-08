/**
 * ============================================================================
 *  File:        wifi.h
 *  Description: WiFi manager - non-blocking connect + auto-reconnect.
 *
 *  Features:
 *   - Config-driven (SSID/PWD from secrets.h).
 *   - Tries to connect in setup(), then continuously auto-reconnects
 *     if the link drops.
 *   - Exposes RSSI for diagnostics.
 *   - No delay() blocking.
 * ============================================================================
 */
/**
*#ifndef WIFI_H
*#define WIFI_H
*/

#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include <Arduino.h>
#include <WiFi.h>

enum class WiFiState : uint8_t {
    DISCONNECTED = 0,
    CONNECTING   = 1,
    CONNECTED    = 2,
    FAILED       = 3,
};

class WiFiManager {
public:
    WiFiManager();

    /** Start connection attempt (non-blocking). */
    void begin();

    /** Run in loop(). Handles retries and connection state. */
    void update();

    /* Accessors */
    bool         isConnected() const;
    WiFiState    state()        const { return _state; }
    int32_t      rssi()         const;       // implemented in .cpp
    IPAddress    localIp()      const;       // implemented in .cpp

    /** Human-readable label, e.g. "CONNECTED (-52 dBm)". */
    const char* statusText() const;

private:
    WiFiState _state = WiFiState::DISCONNECTED;

    uint32_t _lastAttemptMs   = 0;
    uint32_t _connectDeadline = 0;

    static constexpr uint32_t RETRY_INTERVAL_MS   = 10000;  // 10 s between retries
    static constexpr uint32_t CONNECT_TIMEOUT_MS  = 15000;  // 15 s per attempt

    void startConnection();
    void onConnected();
};

#endif // WIFI_H
