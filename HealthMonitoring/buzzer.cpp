/**
 * ============================================================================
 *  File:        buzzer.cpp
 * ============================================================================
 */

#include "buzzer.h"

Buzzer::Buzzer() {}

void Buzzer::begin() {
    pinMode(BUZZER_PIN, OUTPUT);
    writePin(false);
}

void Buzzer::writePin(bool high) {
    _pinState = high;
    digitalWrite(BUZZER_PIN, BUZZER_ACTIVE_HIGH ? high : !high);
}

void Buzzer::on() {
    _mode = BuzzerMode::CONTINUOUS_ON;
    writePin(true);
}

void Buzzer::off() {
    _mode = BuzzerMode::OFF;
    writePin(false);
}

void Buzzer::emergencyBeep() {
    _mode = BuzzerMode::EMERGENCY_BEEP;
    _beepPhaseOn = true;
    _lastToggleMs = millis();
    writePin(true);
}

void Buzzer::setMode(BuzzerMode m) {
    if (m == BuzzerMode::OFF) {
        off();
    } else if (m == BuzzerMode::CONTINUOUS_ON) {
        on();
    } else {
        emergencyBeep();
    }
}

void Buzzer::update() {
    if (_mode != BuzzerMode::EMERGENCY_BEEP) {
        return;
    }

    uint32_t now = millis();
    uint32_t elapsed = now - _lastToggleMs;

    if (_beepPhaseOn && elapsed >= EMERGENCY_BEEP_ON_MS) {
        writePin(false);
        _beepPhaseOn = false;
        _lastToggleMs = now;
    } else if (!_beepPhaseOn && elapsed >= EMERGENCY_BEEP_OFF_MS) {
        writePin(true);
        _beepPhaseOn = true;
        _lastToggleMs = now;
    }
}
