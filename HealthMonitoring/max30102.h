/**
 * ============================================================================
 *  File:        max30102.h
 *  Description: MAX30102 Heart Rate / SpO2 sensor driver - header / class.
 *
 *  This driver:
 *   - Talks to the MAX30102 over I2C (address 0x57).
 *   - Detects finger presence on the sensor.
 *   - Calculates SpO2 and Heart Rate using a state machine.
 *   - Detects sensor errors (no I2C device, FIFO overflow, etc.).
 *
 *  Heart Rate / SpO2 algorithm notes:
 *   - This is a deliberately simple but effective algorithm suitable for
 *     university / demo work. For production medical use you would replace
 *     it with a clinically-validated library (e.g. Maxim's algorithm).
 *   - It uses IR for HR (better penetration) and IR+Red ratio for SpO2.
 * ============================================================================
 */

#ifndef MAX30102_H
#define MAX30102_H

#include <Arduino.h>
#include <Wire.h>
#include "config.h"

/* ============================================================================
 *                            MAX30102 I2C REGISTERS
 * ----------------------------------------------------------------------------
 *  Selected registers only. See MAX30102 datasheet for full list.
 * ============================================================================ */
constexpr uint8_t MAX30102_REG_INT_STATUS_1   = 0x00;
constexpr uint8_t MAX30102_REG_INT_STATUS_2   = 0x01;
constexpr uint8_t MAX30102_REG_INT_ENABLE_1   = 0x02;
constexpr uint8_t MAX30102_REG_INT_ENABLE_2   = 0x03;
constexpr uint8_t MAX30102_REG_FIFO_WR_PTR    = 0x04;
constexpr uint8_t MAX30102_REG_OVF_COUNTER    = 0x05;
constexpr uint8_t MAX30102_REG_FIFO_RD_PTR    = 0x06;
constexpr uint8_t MAX30102_REG_FIFO_DATA      = 0x07;
constexpr uint8_t MAX30102_REG_FIFO_CONFIG    = 0x08;
constexpr uint8_t MAX30102_REG_MODE_CONFIG    = 0x09;
constexpr uint8_t MAX30102_REG_SPO2_CONFIG    = 0x0A;
constexpr uint8_t MAX30102_REG_LED_PA_RED     = 0x0C;
constexpr uint8_t MAX30102_REG_LED_PA_IR      = 0x0D;
constexpr uint8_t MAX30102_REG_PART_ID        = 0xFF;
constexpr uint8_t MAX30102_EXPECTED_PART_ID   = 0x15;

/* ============================================================================
 *                              PUBLIC DATA TYPES
 * ============================================================================ */
enum class SignalQuality : uint8_t {
    NO_FINGER     = 0,
    POOR          = 1,
    GOOD          = 2,
};

enum class FingerStatus : uint8_t {
    NOT_PRESENT     = 0,
    PRESENT         = 1,
};

enum class Max30102Error : uint8_t {
    OK              = 0,
    NOT_DETECTED    = 1,    // I2C device missing
    WRONG_CHIP      = 2,    // Part ID mismatch
    FIFO_OVERFLOW   = 3,
    READ_FAILED     = 4,
};

/* ============================================================================
 *                              MAIN CLASS
 * ============================================================================ */
class Max30102 {
public:
    Max30102();

    /**
     * Initialise I2C bus and configure MAX30102 registers.
     * Returns true on success, false on failure.
     */
    bool begin();

    /**
     * Pull new samples from the FIFO and update internal buffers.
     * Call this frequently (e.g. from a 100 Hz task or fast main loop).
     */
    void update();

    /* -----------------------------------------------------------------------
     *                      ACCESSORS (read-only from outside)
     * --------------------------------------------------------------------- */
    FingerStatus  fingerStatus()   const { return _fingerStatus; }
    
    // Updated accessors: Returns full float precision or rounded integer safely
    float         heartRateFloat() const { return _heartRate; }
    uint8_t       heartRate()      const { return (uint8_t)(_heartRate + 0.5f); }
    uint8_t       spo2()           const { return (uint8_t)(_spo2 + 0.5f); }
    
    uint32_t      irValue()        const { return _irValue; }
    uint32_t      redValue()       const { return _redValue; }
    SignalQuality signalQuality()  const { return _signalQuality; }
    Max30102Error lastError()      const { return _lastError; }
    bool          isHealthy()      const { return _lastError == Max30102Error::OK; }

private:
    /* -----------------------------------------------------------------------
     *                      LOW-LEVEL I2C HELPERS
     * --------------------------------------------------------------------- */
    bool writeRegister(uint8_t reg, uint8_t value);
    bool readRegister(uint8_t reg, uint8_t &value);
    bool readMultiple(uint8_t reg, uint8_t *buffer, uint8_t length);

    /* -----------------------------------------------------------------------
     *                      FIFO / FRESH-DATA HELPERS
     * --------------------------------------------------------------------- */
    bool readFifoSample(uint32_t &red, uint32_t &ir); // Matches max30102.cpp
    bool hasNewSample();

    /* -----------------------------------------------------------------------
     *                      SIGNAL PROCESSING HELPERS
     * --------------------------------------------------------------------- */
    void detectFinger();
    void estimateHeartRate();
    void estimateSpO2();

    /* -----------------------------------------------------------------------
     *                      INTERNAL STATE
     * --------------------------------------------------------------------- */
    FingerStatus  _fingerStatus    = FingerStatus::NOT_PRESENT;
    SignalQuality _signalQuality   = SignalQuality::NO_FINGER;
    Max30102Error _lastError       = Max30102Error::OK;

    uint32_t _irValue               = 0;
    uint32_t _redValue              = 0;

    // Algorithm accumulators
    float    _heartRate             = 0.0f;
    float    _spo2                  = 0.0f;

    // Rolling buffers for DC removal and peak detection
    static constexpr uint8_t BUFFER_LEN = 64;
    uint32_t _irBuffer[BUFFER_LEN]  = {0};
    uint32_t _redBuffer[BUFFER_LEN] = {0};
    uint8_t  _bufferIndex          = 0;
    uint32_t _lastPeakTimeMs       = 0;
    uint32_t _lastSampleTimeMs     = 0;
    float    _dcIr                 = 0.0f;
    float    _dcRed                = 0.0f;
};

#endif // MAX30102_H