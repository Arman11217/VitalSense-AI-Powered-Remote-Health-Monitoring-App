/**
 * ============================================================================
 *  File:        ecg.h
 *  Description: AD8232 ECG analog front-end driver - header.
 * ============================================================================
 */

#ifndef ECG_H
#define ECG_H

#include <Arduino.h>
#include "config.h"

enum class EcgLeadStatus : uint8_t {
    CONNECTED    = 0,    // both LO+ and LO- LOW  = electrodes attached
    DISCONNECTED = 1,    // either or both HIGH    = lead-off
};

class Ecg {
public:
    Ecg();

    /** Configure ADC and lead-off input pins. */
    void begin();

    /** Read ADC + lead-off pins. Call as fast as possible (e.g. 100 Hz). */
    void update();

    /** Last ADC reading in raw counts (0..4095). */
    uint16_t        adcValue()   const { return _adcValue; }

    /** Millivolts estimate, assuming ESP32 ADC reference ~ 3.3 V. */
    float           millivolts() const { return _millivolts; }

    /** Lead-off detector state. */
    EcgLeadStatus   leadStatus() const { return _leadStatus; }

    bool leadConnected() const { return _leadStatus == EcgLeadStatus::CONNECTED; }

private:
    uint16_t       _adcValue   = 0;
    float          _millivolts = 0.0f;
    EcgLeadStatus  _leadStatus = EcgLeadStatus::CONNECTED;
};

#endif // ECG_H
