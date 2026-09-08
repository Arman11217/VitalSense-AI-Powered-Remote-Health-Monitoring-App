/**
 * ============================================================================
 *  File:        buzzer.h
 *  Description: Active buzzer + emergency beep state-machine (non-blocking).
 * ============================================================================
 */

#ifndef BUZZER_H
#define BUZZER_H

#include <Arduino.h>
#include "config.h"

enum class BuzzerMode : uint8_t {
    OFF              = 0,
    CONTINUOUS_ON    = 1,
    EMERGENCY_BEEP   = 2,    // pattern: ON EMERGENCY_BEEP_ON_MS, OFF ... loop
};

class Buzzer {
public:
    Buzzer();

    void begin();
    void update();    // call ~ PERIOD_BUZZER_MS

    void on();
    void off();
    void emergencyBeep();
    void setMode(BuzzerMode m);

    bool isActive() const { return _mode != BuzzerMode::OFF; }

private:
    void writePin(bool high);

    BuzzerMode _mode             = BuzzerMode::OFF;
    bool       _pinState         = false;
    uint32_t   _lastToggleMs     = 0;
    bool       _beepPhaseOn      = false;
};

#endif // BUZZER_H
