#include <Arduino.h>
#include <Wire.h>

#define OLED_SDA 4   // D2
#define OLED_SCL 5   // D1

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\nI2C Scanner - NodeMCU");
  Serial.printf("SDA=GPIO%d SCL=GPIO%d\n", OLED_SDA, OLED_SCL);
  Wire.begin(OLED_SDA, OLED_SCL);
}

void loop() {
  byte error, address;
  int nDevices = 0;
  Serial.println("Scanning I2C bus...");

  for (address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();
    if (error == 0) {
      Serial.printf("I2C device found at 0x%02X\n", address);
      nDevices++;
    } else if (error == 4) {
      Serial.printf("Unknown error at 0x%02X\n", address);
    }
  }

  if (nDevices == 0)
    Serial.println("No I2C devices found - check wiring/pullups");
  else
    Serial.printf("Done. %d device(s) found.\n", nDevices);

  delay(3000);
}