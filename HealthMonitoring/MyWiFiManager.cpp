/**
 * ============================================================================
 *  File:        wifi.cpp
 * ============================================================================
 */

#include <Arduino.h>
#include <WiFi.h>
#include "MyWiFiManager.h"
#include "config.h"
#include "secrets.h"

WiFiManager::WiFiManager() {}

void WiFiManager::begin() {
    // Static IP is optional - leave at 0,0,0,0 to use DHCP.
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(false);   // we do our own reconnect
    WiFi.persistent(false);         // do not write creds to NVS every time
    startConnection();
}

void WiFiManager::startConnection() {
    Serial.print("[WiFi] Connecting to ");
    Serial.print(NET_SSID);
    Serial.print(" ...");
    WiFi.begin(NET_SSID, NET_PASS);

    _state             = WiFiState::CONNECTING;
    _connectDeadline   = millis() + CONNECT_TIMEOUT_MS;
    _lastAttemptMs     = millis();
}

void WiFiManager::onConnected() {
    _state = WiFiState::CONNECTED;
    Serial.println(" OK");
    Serial.print  ("[WiFi] IP : ");
    Serial.println(WiFi.localIP());
    Serial.print  ("[WiFi] RSSI: ");
    Serial.print  (WiFi.RSSI());
    Serial.println(" dBm");
}

void WiFiManager::update() {
    switch (_state) {
        case WiFiState::CONNECTED:
            if (WiFi.status() != WL_CONNECTED) {
                Serial.println("[WiFi] Connection lost. Will retry...");
                _state = WiFiState::DISCONNECTED;
                _lastAttemptMs = millis();   // start the retry timer fresh
            }
            break;

        case WiFiState::CONNECTING:
            if (WiFi.status() == WL_CONNECTED) {
                onConnected();
            } else if (millis() > _connectDeadline) {
                Serial.println(" TIMEOUT");
                _state = WiFiState::FAILED;
                WiFi.disconnect(true);
            }
            break;

        case WiFiState::DISCONNECTED:
        case WiFiState::FAILED:
            if (millis() - _lastAttemptMs >= RETRY_INTERVAL_MS) {
                startConnection();
            }
            break;
    }
}

bool WiFiManager::isConnected() const {
    return _state == WiFiState::CONNECTED && WiFi.status() == WL_CONNECTED;
}

int32_t WiFiManager::rssi() const {
    return WiFi.RSSI();
}

IPAddress WiFiManager::localIp() const {
    return WiFi.localIP();
}

const char* WiFiManager::statusText() const {
    static char buf[32];
    switch (_state) {
        case WiFiState::CONNECTED:
            snprintf(buf, sizeof(buf), "CONNECTED (%ld dBm)", (long)WiFi.RSSI());
            break;
        case WiFiState::CONNECTING:  return "CONNECTING";
        case WiFiState::DISCONNECTED:return "DISCONNECTED";
        case WiFiState::FAILED:      return "FAILED";
        default:                     return "UNKNOWN";
    }
    return buf;
}
