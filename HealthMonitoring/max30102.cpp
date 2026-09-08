/**
* ============================================================================
* File:max30102.cpp
* Description: Robust MAX30102 driver implementation with anti-overflow &
* auto-recovery for multi-tasking/WiFi environments.
* ============================================================================
*/

#include "max30102.h"

/* ============================================================================
* LIFETIME / I2C
* ============================================================================ */
Max30102::Max30102() {
_fingerStatus = FingerStatus::NOT_PRESENT;
_signalQuality = SignalQuality::NO_FINGER;
_lastError= Max30102Error::OK;
_lastSampleTimeMs = millis();
_lastPeakTimeMs = 0;
}

bool Max30102::begin() {
// I2C speed bumped to 400kHz Fast Mode to prevent FIFO backlog during WiFi activity
Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN, 400000UL);

// ---- Check device presence ----
Wire.beginTransmission(MAX30102_I2C_ADDR);
if (Wire.endTransmission() != 0) {
_lastError = Max30102Error::NOT_DETECTED;
return false;
}

// ---- Verify part ID ----
uint8_t partId = 0;
if (!readRegister(MAX30102_REG_PART_ID, partId)) {
_lastError = Max30102Error::READ_FAILED;
return false;
}
if (partId != MAX30102_EXPECTED_PART_ID) {
_lastError = Max30102Error::WRONG_CHIP;
return false;
}

// ---- Software Reset ----
writeRegister(MAX30102_REG_MODE_CONFIG, 0x40);
delay(100);

// ---- Clear FIFO pointers ----
writeRegister(MAX30102_REG_FIFO_WR_PTR, 0x00);
writeRegister(MAX30102_REG_OVF_COUNTER, 0x00);
writeRegister(MAX30102_REG_FIFO_RD_PTR, 0x00);

// ---- FIFO Config: 4 Sample Avg, Enable FIFO Rollover (0x10) ----
// 0x5F = Sample Avg 4 (0x40) + Rollover Enable (0x10) + FIFO Almost Full 15 (0x0F)
writeRegister(MAX30102_REG_FIFO_CONFIG, 0x5F);

// ---- Mode: SpO2 Mode (Red + IR) ----
writeRegister(MAX30102_REG_MODE_CONFIG, 0x03);

// ---- SpO2 Config ----
writeRegister(MAX30102_REG_SPO2_CONFIG,
 (MAX30102_LED_PULSE_WIDTH << 5) | (MAX30102_SAMPLE_RATE & 0x07));

// ---- LED Currents ----
writeRegister(MAX30102_REG_LED_PA_RED, (uint8_t)MAX30102_RED_LED_CURRENT);
writeRegister(MAX30102_REG_LED_PA_IR, (uint8_t)MAX30102_IR_LED_CURRENT);

// ---- Interrupt Enable ----
writeRegister(MAX30102_REG_INT_ENABLE_1, 0xC0); // Enable A_FULL and PP_RDY
writeRegister(MAX30102_REG_INT_ENABLE_2, 0x00);

_lastError = Max30102Error::OK;
return true;
}

void Max30102::update() {
if (_lastError == Max30102Error::NOT_DETECTED || _lastError == Max30102Error::WRONG_CHIP) {
return;
}

// ---- 1. Clear Interrupt Flags & Check Overflow ----
uint8_t intStatus1 = 0;
readRegister(MAX30102_REG_INT_STATUS_1, intStatus1); // Reading status register clears interrupt flags

uint8_t ovf = 0;
readRegister(MAX30102_REG_OVF_COUNTER, ovf);
if (ovf > 0) {
// Clear FIFO Pointers on Overflow to restore stream instantly
writeRegister(MAX30102_REG_FIFO_WR_PTR, 0x00);
writeRegister(MAX30102_REG_OVF_COUNTER, 0x00);
writeRegister(MAX30102_REG_FIFO_RD_PTR, 0x00);
}

// ---- 2. Read ALL backlog samples from FIFO in one go ----
bool samplesRead = false;
while (hasNewSample()) {
uint32_t redRaw = 0, irRaw = 0;
readFifoSample(redRaw, irRaw);

_redValue = redRaw;
_irValue = irRaw;

// Low-pass filter for DC component
_dcIr = (_dcIr * 0.95f) + ((float)irRaw * 0.05f);
_dcRed = (_dcRed * 0.95f) + ((float)redRaw * 0.05f);

// Circular buffer
_irBuffer [_bufferIndex] = irRaw;
_redBuffer[_bufferIndex] = redRaw;
_bufferIndex = (_bufferIndex + 1) % BUFFER_LEN;

samplesRead = true;
}

// ---- 3. Process signal only if fresh samples were processed ----
if (samplesRead) {
detectFinger();
if (_fingerStatus == FingerStatus::PRESENT) {
estimateHeartRate();
estimateSpO2();
} else {
_heartRate = 0.0f;
_spo2 = 0.0f;
}
}
}

/* ============================================================================
* LOW-LEVEL I2C HELPERS
* ============================================================================ */
bool Max30102::writeRegister(uint8_t reg, uint8_t value) {
Wire.beginTransmission(MAX30102_I2C_ADDR);
Wire.write(reg);
Wire.write(value);
return Wire.endTransmission() == 0;
}

bool Max30102::readRegister(uint8_t reg, uint8_t &value) {
Wire.beginTransmission(MAX30102_I2C_ADDR);
Wire.write(reg);
if (Wire.endTransmission(false) != 0) {
return false;
}
Wire.requestFrom(MAX30102_I2C_ADDR, (uint8_t)1);
if (Wire.available() < 1) {
return false;
}
value = Wire.read();
return true;
}

bool Max30102::readMultiple(uint8_t reg, uint8_t *buffer, uint8_t length) {
Wire.beginTransmission(MAX30102_I2C_ADDR);
Wire.write(reg);
if (Wire.endTransmission(false) != 0) {
return false;
}
Wire.requestFrom(MAX30102_I2C_ADDR, length);
for (uint8_t i = 0; i < length && Wire.available(); i++) {
buffer[i] = Wire.read();
}
return true;
}

/* ============================================================================
* FIFO HELPERS
* ============================================================================ */
bool Max30102::hasNewSample() {
uint8_t wrPtr = 0, rdPtr = 0;
if (!readRegister(MAX30102_REG_FIFO_WR_PTR, wrPtr)) return false;
if (!readRegister(MAX30102_REG_FIFO_RD_PTR, rdPtr)) return false;
return wrPtr != rdPtr;
}

bool Max30102::readFifoSample(uint32_t &red, uint32_t &ir) {
uint8_t sample[6];
if (!readMultiple(MAX30102_REG_FIFO_DATA, sample, 6)) {
    return false;
}

red = ((uint32_t)sample[0] << 16) |
 ((uint32_t)sample[1] << 8) |
 ((uint32_t)sample[2]);
red &= 0x3FFFF; // 18-bit

ir = ((uint32_t)sample[3] << 16) |
 ((uint32_t)sample[4] << 8) |
 ((uint32_t)sample[5]);
ir &= 0x3FFFF;
return true;
}

/* ============================================================================
* SIGNAL PROCESSING
* ============================================================================ */
void Max30102::detectFinger() {
const float FINGER_THRESHOLD = 50000.0f;
const float MIN_AC_AMPLITUDE = 2000.0f;

if (_dcIr < FINGER_THRESHOLD) {
_fingerStatus = FingerStatus::NOT_PRESENT;
_signalQuality = SignalQuality::NO_FINGER;
return;
}

_fingerStatus = FingerStatus::PRESENT;

uint32_t irMin = _irBuffer[0], irMax = _irBuffer[0];
for (uint8_t i = 1; i < BUFFER_LEN; i++) {
if (_irBuffer[i] < irMin) irMin = _irBuffer[i];
if (_irBuffer[i] > irMax) irMax = _irBuffer[i];
}
float ac = (float)(irMax - irMin);

_signalQuality = (ac > MIN_AC_AMPLITUDE) ? SignalQuality::GOOD
: SignalQuality::POOR;
}
/**
void Max30102::estimateHeartRate() {
float acIr = (float)_irValue - _dcIr;

static float prevAcIr = 0;
float acRange = 0;
for (uint8_t i = 0; i < BUFFER_LEN; i++) {
float v = (float)_irBuffer[i] - _dcIr;
if (v < 0) v = -v;
if (v > acRange) acRange = v;
}
const float PEAK_FRACTION = 0.6f;

bool risingEdge = (prevAcIr < acRange * PEAK_FRACTION) &&
 (acIr >= acRange * PEAK_FRACTION);
prevAcIr = acIr;

uint32_t now = millis();
if (risingEdge && (now - _lastPeakTimeMs) > 250) { // refractory 250 ms
if (_lastPeakTimeMs != 0) {
float interval = (float)(now - _lastPeakTimeMs) / 1000.0f;
if (interval > 0.25f) {
float instantHr = 60.0f / interval;
_heartRate = (_heartRate == 0) ? instantHr
 : (_heartRate * 0.8f + instantHr * 0.2f);
}
}
_lastPeakTimeMs = now;
}
}
*/
void Max30102::estimateHeartRate() {
uint32_t now = millis();

// 1. Calculate Peak-to-Peak (AC amplitude) to detect valid pulse signal
uint32_t irMin = _irBuffer[0], irMax = _irBuffer[0];
for (uint8_t i = 1; i < BUFFER_LEN; i++) {
if (_irBuffer[i] < irMin) irMin = _irBuffer[i];
if (_irBuffer[i] > irMax) irMax = _irBuffer[i];
}
float acAmplitude = (float)(irMax - irMin);

// If signal noise is too small, skip calculation (Prevents low erratic BPM)
if (acAmplitude < 800.0f) {
return;
}

// 2. High-pass/Dynamic threshold peak detection
float acIr = (float)_irValue - _dcIr;
float threshold = acAmplitude * 0.35f; // Dynamic 35% peak threshold

static float prevAcIr = 0.0f;
bool peakDetected = (prevAcIr < threshold) && (acIr >= threshold);
prevAcIr = acIr;

// 3. Refractory Period Check (Between 300ms [200 BPM] and 1500ms [40 BPM])
if (peakDetected) {
if (_lastPeakTimeMs != 0) {
uint32_t timeDiff = now - _lastPeakTimeMs;

// Only consider valid human heart rate range (40 - 200 BPM)
if (timeDiff >= 300 && timeDiff <= 1500) {
float instantHr = 60000.0f / (float)timeDiff;

// Instant response on first couple of beats
if (_heartRate < 30.0f || _heartRate > 200.0f) {
_heartRate = instantHr; // Quick start (1-2 seconds)
} else {
// Smooth Exponential Moving Average (EMA)
_heartRate = (_heartRate * 0.75f) + (instantHr * 0.25f);
}
}
}
_lastPeakTimeMs = now;
}

// Reset peak timer if finger was removed/re-inserted long ago
if (now - _lastPeakTimeMs > 2000) {
_lastPeakTimeMs = 0;
}
}
void Max30102::estimateSpO2() {
auto acDC = [&](uint32_t *buf) -> float {
uint32_t mn = buf[0], mx = buf[0];
for (uint8_t i = 1; i < BUFFER_LEN; i++) {
if (buf[i] < mn) mn = buf[i];
if (buf[i] > mx) mx = buf[i];
}
return ((float)(mx - mn)) / 2.0f;
};

float acRed = acDC(_redBuffer);
float acIr = acDC(_irBuffer);

if (_dcRed < 1.0f || _dcIr < 1.0f || acIr < 1.0f) {
return;
}

float R = (acRed / _dcRed) / (acIr / _dcIr);
float spo2 = 110.0f - 25.0f * R;

if (spo2 < 70.0f) spo2 = 70.0f;
if (spo2 > 100.0f) spo2 = 100.0f;

_spo2 = (_spo2 == 0.0f) ? spo2 : (_spo2 * 0.8f + spo2 * 0.2f);
}

