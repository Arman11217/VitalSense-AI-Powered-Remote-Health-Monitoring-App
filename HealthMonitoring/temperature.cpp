/**
 * ============================================================================
 *  File:        temperature.cpp
 *
 *  Note: this module uses 5-sample majority voting. The KY-013 / similar
 *  digital temperature modules can briefly glitch when the comparator
 *  crosses its threshold. Voting prevents false HOT/ NORMAL flips from
 *  a single noise spike.
 *
 *  Hardware side also recommended:
 *    - Turn the on-board potentiometer counter-clockwise all the way
 *      so that room temperature is well inside the NORMAL band.
 *    - Module VCC should be 3.3 V (same rail as ESP32), not 5 V.
 * ============================================================================
 */

#include "temperature.h"

Temperature::Temperature() {}

void Temperature::begin() {
    pinMode(TEMP_DIGITAL_PIN, INPUT);
    // Don't enable internal pull-up - the module has its own pull-up on D0.
    // Enabling another pull-up would distort the comparator threshold.
    bool initialHot = TEMP_ACTIVE_HIGH ? (digitalRead(TEMP_DIGITAL_PIN) == HIGH)
                                       : (digitalRead(TEMP_DIGITAL_PIN) == LOW);
    _digitalRaw = digitalRead(TEMP_DIGITAL_PIN);

    // Prime the sample window
    for (uint8_t i = 0; i < SAMPLE_COUNT; i++) {
        _samples[i] = _digitalRaw;
    }
    if (initialHot) _highCount = SAMPLE_COUNT;
    else            _lowCount  = SAMPLE_COUNT;
    _status = classify(initialHot);
}

void Temperature::update() {
    bool raw = digitalRead(TEMP_DIGITAL_PIN);
    _digitalRaw = raw;

    // Convert raw reading to "is currently HOT" based on module polarity.
    bool isHot = TEMP_ACTIVE_HIGH ? (raw == HIGH) : (raw == LOW);

    // Sliding window: subtract old sample, add new sample
    bool oldSample = _samples[_sampleIndex];
    if (oldSample) _highCount--; else _lowCount--;
    if (isHot)    _highCount++; else _lowCount--;

    _samples[_sampleIndex] = isHot;
    _sampleIndex = (_sampleIndex + 1) % SAMPLE_COUNT;

    _status = classify(isHot);
}

TemperatureStatus Temperature::classify(bool /*currentHot*/) {
    // Majority vote on the 5-sample window.
    if (_highCount >= 3) return TemperatureStatus::HOT;
    if (_lowCount  >= 3) return TemperatureStatus::NORMAL;
    // Mixed window -> hold previous status (hysteresis) to avoid flicker.
    return _status;
}

const char *Temperature::statusText() const {
    switch (_status) {
        case TemperatureStatus::NORMAL: return "NORMAL";
        case TemperatureStatus::HOT:    return "HOT";
        default:                        return "ERROR";
    }
}
