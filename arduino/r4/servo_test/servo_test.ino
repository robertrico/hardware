// Servo Control Sketch for Arduino UNO R4
// Wiring: Black (GND) -> GND pin, Red (VCC) -> 5V pin, White (Signal) -> Pin 13

#include <Servo.h>

Servo myServo;

const int SIGNAL_PIN = 13; // White wire - PWM signal

void setup() {
  Serial.begin(115200);
  Serial.println("Arduino UNO R4 - Servo Test");

  // Attach servo to signal pin
  myServo.attach(SIGNAL_PIN);

  Serial.println("Servo initialized");
  Serial.println("Starting sweep pattern...");
}

void loop() {
  // Sweep from 0 to 180 degrees
  Serial.println("Sweeping 0 -> 180");
  for (int pos = 0; pos <= 180; pos++) {
    myServo.write(pos);
    delay(2);
  }

  delay(300); // Pause at 180 degrees

  // Sweep back from 180 to 0 degrees
  Serial.println("Sweeping 180 -> 0");
  for (int pos = 180; pos >= 0; pos--) {
    myServo.write(pos);
    delay(2);
  }

  delay(300); // Pause at 0 degrees
}
