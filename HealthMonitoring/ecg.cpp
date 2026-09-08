/**
 * ============================================================================
 *  File:        ecg.cpp
 *  Description: AD8232 ECG analog front-end driver implementation.
 *
 *  Notes on the AD8232:
 *   - OUTPUT pin emits ~0..3.3 V analog signal centered at ~1.5 V.
 *   - LO+ and LO- go HIGH when their respective electrode is OFF the body.
 *     So lead is "connected" only when BOTH are LOW.
 * ============================================================================
 */

#include "ecg.h"

#define ADC_VREF       3.3f
#define ADC_FULL_SCALE 4095.0f

Ecg::Ecg() {}

void Ecg::begin() {
    pinMode(ECG_OUTPUT_PIN,   INPUT);
    pinMode(ECG_LO_PLUS_PIN,  INPUT);
    pinMode(ECG_LO_MINUS_PIN, INPUT);

    // ESP32 ADC config: 12-bit, full-scale ~ 3.3 V, no attenuation by default
    analogReadResolution(12);                      // 0..4095
    analogSetPinAttenuation(ECG_OUTPUT_PIN, ADC_11db);   // full 0..3.3 V range
}

void Ecg::update() {
    // ---- Lead-off detection ----
    // LO+ and LO- are HIGH when the corresponding electrode is NOT on the body.
    bool loPlusOff  = digitalRead(ECG_LO_PLUS_PIN)  == HIGH;
    bool loMinusOff = digitalRead(ECG_LO_MINUS_PIN) == HIGH;
    _leadStatus = (loPlusOff || loMinusOff) ? EcgLeadStatus::DISCONNECTED
                                            : EcgLeadStatus::CONNECTED;

    // ---- ADC sample ----
    _adcValue = (uint16_t)analogRead(ECG_OUTPUT_PIN);
    _millivolts = ((float)_adcValue * ADC_VREF * 1000.0f) / ADC_FULL_SCALE;
}
