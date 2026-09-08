/**
 * ============================================================================
 *  File:        temperature.h
 *  Description: Digital temperature module (KY-013 / similar) driver.
 * ============================================================================
 */

#ifndef TEMPERATURE_H
#define TEMPERATURE_H

#include <Arduino.h>
#include "config.h"

enum class TemperatureStatus : uint8_t {
    NORMAL = 0,
    HOT    = 1,
    ERROR  = 2,
};

class Temperature {
public:
    Temperature();

    void begin();
    void update();

    TemperatureStatus status()    const { return _status; }
    bool              digitalRaw() const { return _digitalRaw; }

    /** Human-readable string for Serial output. */
    const char *statusText() const;

private:
    bool              _digitalRaw = false;
    TemperatureStatus _status     = TemperatureStatus::NORMAL;

    // ---- Debounce / majority-vote state ----
    static constexpr uint8_t SAMPLE_COUNT = 5;
    bool           _samples[SAMPLE_COUNT] = {false};
    uint8_t        _sampleIndex           = 0;
    uint8_t        _highCount            = 0;
    uint8_t        _lowCount             = 0;

    TemperatureStatus classify(bool isHot);
};

#endif // TEMPERATURE_H
