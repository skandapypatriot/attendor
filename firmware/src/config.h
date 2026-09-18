#pragma once

// ============ HEADLESS MODE ============
// OLED_ENABLED = 1 -> boot without any display attached
// OLED_ENABLED = 0 -> 0.96" OLED 128x64 (SSD1306, I2C) gives feedback
// In HEADLESS mode all on-device feedback is printed to Serial only.
#define OLED_ENABLED 0

// ============ REMOTE LOGGING ============
// Set to 1 to push device logs to Firebase; the Python worker's
// web UI (live log page) will show them.
#define REMOTE_LOGGING 1

// ============ WIFI ============
#define WIFI_SSID "YourWiFiSSID"
#define WIFI_PASS "YourWiFiPassword"

// ============ FIREBASE (from create_device.py output) ============
#define FIREBASE_API_KEY "AIzaSyXXXXXXXXXXXX"
#define FIREBASE_DATABASE_URL "https://attendor-saas-default-rtdb.firebaseio.com"
#define SCHOOL_ID "my-school"
#define DEVICE_ID "U4lW...device-auth-uid"

#define FIREBASE_AUTH_EMAIL "device-123456@attendor.in"
#define FIREBASE_AUTH_PASSWORD "deviceAuthPassword"

// ============ RC522 PINOUT (ESP32 DevKit) ============
#define RC522_SS_PIN 5
#define RC522_RST_PIN 4
#define RC522_SCK_PIN 18
#define RC522_MOSI_PIN 23
#define RC522_MISO_PIN 19

// ============ OLED 128x64 (SSD1306, I2C) ============
#define OLED_SDA_PIN 21
#define OLED_SCL_PIN 22
#define OLED_ADDR 0x3C

// ============ BEHAVIOR ============
#define SCAN_POST_TIMEOUT_MS 15000
#define COMMAND_POLL_MS 5000
#define TOKEN_REFRESH_MS 300000
#define QUEUE_MAX_ENTRIES 30