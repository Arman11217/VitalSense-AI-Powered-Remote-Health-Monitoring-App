/**
 * ============================================================================
 *  File:        display.cpp
 * ============================================================================
 */

#include "display.h"
#include "config.h"
#include "max30102.h"
#include "ecg.h"
#include "temperature.h"

Display::Display() {}

void Display::printBanner() {
    Serial.println();
    Serial.println("=============================================");
    Serial.print ("  ");
    Serial.print (FIRMWARE_NAME);
    Serial.print (" v");
    Serial.println(FIRMWARE_VERSION);
    Serial.print ("  Board : "); Serial.println(DEVICE_MODEL);
    
    // ✅ Phase 1 এর বদলে Phase 2 (WiFi & Firebase Active) দেখানোর জন্য আপডেট করা হলো
#if FEATURE_WIFI && FEATURE_FIREBASE
    Serial.println("  Phase : 2 (WiFi & Firebase Active)");
#elif FEATURE_WIFI
    Serial.println("  Phase : 2 (WiFi Active)");
#else
    Serial.println("  Phase : 1 (sensor only)");
#endif

    Serial.println("=============================================");
}

static const char *fingerText(FingerStatus f) {
    return (f == FingerStatus::PRESENT) ? "DETECTED" : "NOT DETECTED";
}

static const char *signalText(SignalQuality q) {
    switch (q) {
        case SignalQuality::GOOD:       return "GOOD";
        case SignalQuality::POOR:       return "POOR";
        default:                        return "NO FINGER";
    }
}

static const char *leadText(EcgLeadStatus s) {
    return (s == EcgLeadStatus::CONNECTED) ? "CONNECTED" : "DISCONNECTED";
}

void Display::printFrame(const Max30102 &m, const Ecg &e, const Temperature &t) {
    Serial.println("=============================================");
    Serial.print("Heart Rate     : ");
    if (m.heartRate() > 0) {
        Serial.print(m.heartRate()); Serial.println(" BPM");
    } else {
        Serial.println("-- BPM");
    }

    Serial.print("SpO2           : ");
    if (m.spo2() > 0) {
        Serial.print(m.spo2()); Serial.println(" %");
    } else {
        Serial.println("-- %");
    }

    Serial.print("IR Value       : "); Serial.println(m.irValue());
    Serial.print("Red Value      : "); Serial.println(m.redValue());
    Serial.print("Finger         : "); Serial.println(fingerText(m.fingerStatus()));
    Serial.print("Signal Quality : "); Serial.println(signalText(m.signalQuality()));

    Serial.print("ECG ADC        : "); Serial.println(e.adcValue());
    Serial.print("Lead Status    : "); Serial.println(leadText(e.leadStatus()));

    Serial.print("Temperature    : "); Serial.println(t.statusText());
    Serial.println("=============================================");
    Serial.println();
}