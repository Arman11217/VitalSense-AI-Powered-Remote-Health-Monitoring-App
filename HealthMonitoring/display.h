/**
 * ============================================================================
 *  File:        display.h
 *  Description: Serial Monitor dashboard printer. Pure formatting - reads
 *               values from the sensor classes; does NOT own them.
 * ============================================================================
 */

#ifndef DISPLAY_H
#define DISPLAY_H

#include <Arduino.h>

// forward declarations - we only read these, not own them
class Max30102;
class Ecg;
class Temperature;

class Display {
public:
    Display();

    /** Print a single dashboard frame. */
    void printFrame(const Max30102 &m, const Ecg &e, const Temperature &t);

    /** Pretty banner used at startup. */
    void printBanner();
};

#endif // DISPLAY_H
