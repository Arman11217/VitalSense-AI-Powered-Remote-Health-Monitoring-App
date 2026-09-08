/**
 * ============================================================================
 *  I2C Scanner - Quick hardware diagnostic
 *  Upload this to verify MAX30102 (0x57) is detected.
 *  Then re-upload HealthMonitoring.ino after.
 * ============================================================================
 */

#include <Wire.h>

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n=== I2C Scanner ===");

    // Use the same pins as the main sketch
    Wire.begin(21, 22);  // SDA=21, SCL=22
    Serial.println("Scanning I2C bus (SDA=21, SCL=22)...");
}

void loop() {
    uint8_t found = 0;
    for (uint8_t addr = 1; addr < 127; addr++) {
        Wire.beginTransmission(addr);
        if (Wire.endTransmission() == 0) {
            Serial.print("FOUND at 0x");
            if (addr < 16) Serial.print("0");
            Serial.print(addr, HEX);
            if (addr == 0x57) Serial.print("  <-- MAX30102 (expected)");
            Serial.println();
            found++;
        }
    }

    if (found == 0) {
        Serial.println("NO I2C devices found. Check wiring!");
    } else {
        Serial.print("Total: ");
        Serial.print(found);
        Serial.println(" device(s)");
    }

    Serial.println("--- retry in 2s ---\n");
    delay(2000);
}