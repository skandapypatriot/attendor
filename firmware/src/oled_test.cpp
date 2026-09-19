#include <Arduino.h>
#include <Wire.h>
#include <U8g2lib.h>
#include "config.h"

U8G2_SH1106_128X64_NONAME_F_SW_I2C display(U8G2_R0, OLED_SCL_PIN, OLED_SDA_PIN, U8X8_PIN_NONE);
bool oledPresent = false;

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("========================================");
  Serial.println("  SH1106 OLED 128x64 Test");
  Serial.println("========================================");

  oledPresent = display.begin();
  if (!oledPresent) {
    Serial.println("ERROR: OLED not detected on I2C!");
    Serial.println("Check SDA/SCL wiring and power.");
    while (true) delay(1000);
  }

  Serial.println("OLED found! Running tests...");
  Serial.println();

  // Test 1: Fill screen white then black
  Serial.print("Test 1: Full screen fill... ");
  display.clearDisplay();
  display.sendBuffer();
  delay(500);
  display.setDrawColor(1);
  display.drawBox(0, 0, 128, 64);
  display.sendBuffer();
  delay(500);
  display.clearDisplay();
  display.sendBuffer();
  delay(300);
  Serial.println("OK");

  // Test 2: Draw border frame
  Serial.print("Test 2: Border frame... ");
  display.drawFrame(0, 0, 128, 64);
  display.drawFrame(2, 2, 124, 60);
  display.sendBuffer();
  delay(600);
  display.clearDisplay();
  Serial.println("OK");

  // Test 3: Diagonal lines
  Serial.print("Test 3: Diagonal lines... ");
  for (int i = 0; i < 128; i += 8) {
    display.drawLine(i, 0, 127 - i, 63);
  }
  for (int i = 0; i < 64; i += 8) {
    display.drawLine(0, i, 127, 63 - i);
  }
  display.sendBuffer();
  delay(600);
  display.clearDisplay();
  Serial.println("OK");

  // Test 4: Font test - all fonts used in firmware
  Serial.print("Test 4: Fonts... ");

  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(10, 16, "HEADING 7x14B");

  display.setFont(u8g2_font_6x12_tf);
  display.drawStr(10, 32, "Body text 6x12");

  display.setFont(u8g2_font_5x7_tf);
  display.drawStr(10, 44, "Small 5x7 for details");

  display.setFont(u8g2_font_4x6_tr);
  display.drawStr(10, 54, "Tiny 4x6 footer");

  display.sendBuffer();
  delay(1500);
  display.clearDisplay();
  Serial.println("OK");

  // Test 5: Circles and boxes
  Serial.print("Test 5: Shapes... ");
  display.drawCircle(32, 32, 28);
  display.drawCircle(32, 32, 20);
  display.drawFilledEllipse(96, 32, 28, 24);
  display.drawFrame(70, 8, 52, 48);
  display.drawBox(80, 18, 32, 28);
  display.sendBuffer();
  delay(1000);
  display.clearDisplay();
  Serial.println("OK");

  // Test 6: Scrolling text like boot sequence
  Serial.print("Test 6: Boot sequence simulation... ");
  const char *steps[] = {"OLED", "RFID", "Storage", "WiFi", "NTP", "Firebase", "Link"};
  int totalSteps = 7;
  for (int pass = 0; pass < 2; pass++) {
    for (int s = 0; s < totalSteps; s++) {
      display.clearDisplay();
      display.setFont(u8g2_font_7x14B_tf);
      display.drawStr(20, 14, "Attendor Boot");
      display.setFont(u8g2_font_4x6_tr);
      display.drawStr(0, 28, ("Step " + String(s + 1) + "/" + String(totalSteps) + ": " + steps[s]).c_str());

      // Progress bar
      int barW = (s + 1) * 128 / totalSteps;
      display.drawFrame(0, 52, 128, 10);
      display.drawBox(1, 53, barW - 2, 8);

      // Checkmarks for done, check for current
      int yOff = 38;
      for (int i = 0; i <= s; i++) {
        int x = 2 + (i % 4) * 32;
        int y = yOff + (i / 4) * 8;
        display.setFont(u8g2_font_4x6_tr);
        display.drawStr(x, y, (String("[OK] ") + steps[i]).c_str());
      }

      display.sendBuffer();
      delay(200);
    }
  }
  delay(500);
  display.clearDisplay();
  Serial.println("OK");

  // Test 7: QR code area placeholder
  Serial.print("Test 7: QR area + MAC text... ");
  display.clearDisplay();
  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(20, 12, "UNLINKED");
  display.setFont(u8g2_font_4x6_tr);
  display.drawStr(30, 62, "AA:BB:CC:DD:EE:FF");

  // Draw fake QR pattern
  for (int y = 16; y < 56; y += 3) {
    for (int x = 36; x < 76; x += 3) {
      if ((x + y) % 6 == 0 || (x * y) % 5 == 0) {
        display.drawBox(x, y, 2, 2);
      }
    }
  }
  display.sendBuffer();
  delay(1500);

  // Done
  display.clearDisplay();
  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(10, 20, "ALL TESTS");
  display.drawStr(10, 40, "PASSED");
  display.setFont(u8g2_font_5x7_tf);
  display.drawStr(10, 58, "OLED is working!");

  Serial.println();
  Serial.println("========================================");
  Serial.println("  ALL TESTS PASSED");
  Serial.println("========================================");
}

int frameCount = 0;

void loop() {
  display.clearDisplay();

  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(10, 16, "OLED Test OK");

  display.setFont(u8g2_font_5x7_tf);
  display.drawStr(10, 32, "Live loop running");

  char buf[32];
  snprintf(buf, sizeof(buf), "Frame: %d", frameCount++);
  display.drawStr(10, 48, buf);

  // Animated dot
  int dx = (millis() / 20) % 128;
  display.drawBox(dx, 58, 6, 6);

  display.sendBuffer();
  delay(100);
}
