// Rapid Blink Sketch for Arduino UNO R4 LED Matrix
// Blinks patterns rapidly across the 12x8 LED matrix

#include "Arduino_LED_Matrix.h"

ArduinoLEDMatrix matrix;

// Frame buffer for the 12x8 LED matrix (3 x 32-bit integers)
uint32_t frame[3] = {0, 0, 0};

void setup() {
  Serial.begin(115200);
  matrix.begin();
  Serial.println("Arduino UNO R4 Rapid Blink - LED Matrix");
}

void loop() {
  // Pattern 1: Horizontal sweep (left to right)
  for (int col = 0; col < 12; col++) {
    clearFrame();
    setColumn(col);
    matrix.loadFrame(frame);
    delay(30);
  }

  // Pattern 2: Vertical sweep (top to bottom)
  for (int row = 0; row < 8; row++) {
    clearFrame();
    setRow(row);
    matrix.loadFrame(frame);
    delay(30);
  }

  // Pattern 3: Diagonal sweep
  for (int i = 0; i < 12; i++) {
    clearFrame();
    for (int j = 0; j < 8; j++) {
      if ((i + j) % 2 == 0) {
        setPixel(i, j);
      }
    }
    matrix.loadFrame(frame);
    delay(50);
  }

  // Pattern 4: All blink rapidly
  for (int i = 0; i < 10; i++) {
    allOn();
    matrix.loadFrame(frame);
    delay(50);
    clearFrame();
    matrix.loadFrame(frame);
    delay(50);
  }

  // Pattern 5: Random sparkle
  for (int i = 0; i < 100; i++) {
    clearFrame();
    for (int j = 0; j < 20; j++) {
      int x = random(12);
      int y = random(8);
      setPixel(x, y);
    }
    matrix.loadFrame(frame);
    delay(40);
  }
}

// Helper functions for LED matrix manipulation
void clearFrame() {
  frame[0] = 0;
  frame[1] = 0;
  frame[2] = 0;
}

void allOn() {
  frame[0] = 0xFFFFFFFF;
  frame[1] = 0xFFFFFFFF;
  frame[2] = 0xFFFFFFFF;
}

void setPixel(int x, int y) {
  // The LED matrix is organized as 3 x 32-bit integers
  // Each row is 12 bits wide, packed into the 32-bit integers
  if (x < 0 || x >= 12 || y < 0 || y >= 8) return;

  int bitPosition = y * 12 + x;
  int frameIndex = bitPosition / 32;
  int bitIndex = 31 - (bitPosition % 32);

  if (frameIndex < 3) {
    frame[frameIndex] |= (1UL << bitIndex);
  }
}

void setRow(int row) {
  for (int col = 0; col < 12; col++) {
    setPixel(col, row);
  }
}

void setColumn(int col) {
  for (int row = 0; row < 8; row++) {
    setPixel(col, row);
  }
}
