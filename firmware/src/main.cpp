#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>
#include <Preferences.h>

#if OLED_ENABLED
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#else
#define SSD1306_SWITCHCAPVCC 0
#define SSD1306_WHITE 1
#endif

#include "config.h"

#define SS_PIN RC522_SS_PIN
#define RST_PIN RC522_RST_PIN

MFRC522 mfrc522(SS_PIN, RST_PIN);
WiFiClientSecure secureClient;
Preferences prefs;

#if OLED_ENABLED
Adafruit_SSD1306 display(128, 64, &Wire, -1);
#endif

String token = "";
unsigned long tokenAt = 0;

bool pendingEnroll = false;
bool timeValid = false;
bool processingScan = false;

const char *NVS_NS = "attendor";
const char *Q_START = "qStart";
const char *Q_NEXT = "qNext";

struct HttpResult {
  int code;
  String body;
};

void logLine(const String &level, const String &msg) {
  Serial.printf("[%10lu] %-6s %s\n", millis(), level.c_str(), msg.c_str());
#if REMOTE_LOGGING
  if (WiFi.status() == WL_CONNECTED && token.length() > 0) {
    JsonDocument doc;
    doc["ts"] = (long)time(nullptr) * 1000L;
    doc["level"] = level;
    doc["message"] = msg;
    String body;
    serializeJson(doc, body);
    String url = String(FIREBASE_DATABASE_URL) + "/schools/" SCHOOL_ID +
                 "/devices/" DEVICE_ID "/logs.json?auth=" + token;
    HTTPClient http;
    http.begin(secureClient, url);
    http.addHeader("Content-Type", "application/json");
    http.POST(body);
    http.end();
  }
#endif
}

#if OLED_ENABLED
void show(int size, const String &line1, const String &line2 = "") {
  display.clearDisplay();
  display.setTextSize(size);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println(line1);
  if (line2.length()) display.println(line2);
  display.display();
}
#else
void show(int size, const String &line1, const String &line2 = "") {
  (void)size;
  logLine("INFO", line1 + (line2.length() ? " " + line2 : ""));
}
#endif

String uidToString(const byte *uid, byte len) {
  String s;
  for (byte i = 0; i < len; i++) {
    if (uid[i] < 0x10) s += "0";
    s += String(uid[i], HEX);
  }
  s.toUpperCase();
  return s;
}

String urlWithAuth(const String &path) {
  return String(FIREBASE_DATABASE_URL) + "/" + path + ".json?auth=" + token;
}

HttpResult httpRequest(const String &method, const String &url, const String &body = "") {
  HttpResult r = {0, ""};
  HTTPClient http;
  http.setTimeout(10000);
  http.begin(secureClient, url);
  if (body.length()) {
    http.addHeader("Content-Type", "application/json");
    r.code = http.sendRequest(method.c_str(), body);
  } else {
    r.code = http.sendRequest(method.c_str());
  }
  r.body = http.getString();
  http.end();
  return r;
}

bool signIn() {
  String url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key="
               FIREBASE_API_KEY;
  String body = String("{\"email\":\"") + FIREBASE_AUTH_EMAIL +
                "\",\"password\":\"" FIREBASE_AUTH_PASSWORD "\",\"returnSecureToken\":true}";
  HttpResult r = httpRequest("POST", url, body);
  if (r.code != 200) {
    logLine("ERROR", "signIn failed: " + String(r.code) + " " + r.body);
    return false;
  }
  JsonDocument doc;
  deserializeJson(doc, r.body);
  token = doc["idToken"] | "";
  tokenAt = millis();
  return token.length() > 0;
}

bool ensureOnline() {
  if (WiFi.status() != WL_CONNECTED) return false;
  if (token.length() == 0 || millis() - tokenAt > TOKEN_REFRESH_MS) {
    if (!signIn()) return false;
  }
  return true;
}

void processCard(const String &tagUid) {
  processingScan = true;
  String type = pendingEnroll ? "enroll" : "attend";
  long ts = timeValid ? (long)time(nullptr) * 1000L : millis();
  logLine("INFO", String("card read type=") + type + " tag=" + tagUid);

  bool online = ensureOnline();
  if (!online) {
    int start = prefs.getInt(Q_START, 0);
    int next = prefs.getInt(Q_NEXT, 0);
    if (next - start >= QUEUE_MAX_ENTRIES) {
      logLine("WARN", "queue full, scan dropped");
      show(1, "OFFLINE", "queue full");
      processingScan = false;
      return;
    }
    JsonDocument doc;
    doc["tagUid"] = tagUid;
    doc["ts"] = ts;
    doc["type"] = type;
    String body;
    serializeJson(doc, body);
    prefs.putString((String("q") + next).c_str(), body);
    prefs.putInt(Q_NEXT, next + 1);
    logLine("WARN", "offline, scan queued (#" + String(next) + ")");
    show(1, "OFFLINE - queued");
    processingScan = false;
    return;
  }

  JsonDocument doc;
  doc["tagUid"] = tagUid;
  doc["ts"] = ts;
  doc["type"] = type;
  String body;
  serializeJson(doc, body);

  HttpResult r = httpRequest("POST",
      urlWithAuth("schools/" SCHOOL_ID "/devices/" DEVICE_ID "/scans"), body);
  if (r.code != 200) {
    logLine("ERROR", "scan push failed: " + String(r.code));
    show(1, "SEND FAIL");
    processingScan = false;
    return;
  }
  JsonDocument result;
  deserializeJson(result, r.body);
  String scanId = result["name"] | "";

  show(1, "SCANNING...");
  String responsePath = "schools/" SCHOOL_ID "/devices/" DEVICE_ID "/responses/" + scanId;
  unsigned long started = millis();
  while (millis() - started < SCAN_POST_TIMEOUT_MS) {
    HttpResult rr = httpRequest("GET", urlWithAuth(responsePath));
    if (rr.code == 200 && rr.body != "null" && rr.body.length() > 2) {
      JsonDocument rd;
      deserializeJson(rd, rr.body);
      bool ok = rd["ok"] | false;
      String msg = rd["message"] | "";
      logLine(ok ? "INFO" : "WARN", String("result ok=") + (ok ? "true" : "false") +
                                   " msg=" + msg);
      show(ok ? 2 : 1, ok ? "PRESENT" : "NOT OK", msg.length() > 14 ? msg.substring(0, 14) : msg);
      break;
    }
    delay(200);
  }
  processingScan = false;
}

void pollEnrollCommand() {
  if (!ensureOnline()) return;
  HttpResult r = httpRequest("GET",
      urlWithAuth("schools/" SCHOOL_ID "/devices/" DEVICE_ID "/enrollCommand"));
  bool active = (r.code == 200 && r.body != "null" && r.body.length() > 2);
  if (active && !pendingEnroll) {
    JsonDocument doc;
    deserializeJson(doc, r.body);
    String studentUid = doc["studentUid"] | "";
    pendingEnroll = studentUid.length() > 0;
    logLine("INFO", String("enroll command: bind card for ") +
                    (studentUid.length() ? studentUid : "student"));
    show(1, "ASSIGN CARD", "scan now");
  } else if (!active && pendingEnroll) {
    pendingEnroll = false;
    logLine("INFO", "enroll command done");
    show(1, "TAP CARD");
  }
}

void flushQueue() {
  int start = prefs.getInt(Q_START, 0);
  int next = prefs.getInt(Q_NEXT, 0);
  if (start >= next) return;
  if (!ensureOnline()) return;

  String key = String("q") + start;
  String entry = prefs.getString(key.c_str(), "");
  if (entry.length() == 0) return;

  HttpResult r = httpRequest("POST",
      urlWithAuth("schools/" SCHOOL_ID "/devices/" DEVICE_ID "/scans"), entry);
  if (r.code == 200) {
    prefs.remove(key.c_str());
    prefs.putInt(Q_START, start + 1);
    logLine("INFO", "flushed queued scan #" + String(start));
  } else {
    logLine("ERROR", "flush failed for #" + String(start) + ": " + String(r.code));
  }
}

void setup() {
  Serial.begin(115200);
  logLine("INFO", "Attendor device booting");

#if OLED_ENABLED
  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    logLine("WARN", "OLED init failed");
  } else {
    show(0, "ATTENDOR", "booting");
  }
#endif

  SPI.begin(RC522_SCK_PIN, RC522_MISO_PIN, RC522_MOSI_PIN, RC522_SS_PIN);
  mfrc522.PCD_Init();

  prefs.begin(NVS_NS, false);

  show(1, "CONNECTING", "wifi");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  unsigned long started = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - started < 30000) {
    delay(250);
  }
  if (WiFi.status() == WL_CONNECTED) {
    logLine("INFO", "wifi connected: " + String(WiFi.localIP().toString()));
    configTime(0, 0, "time.google.com", "pool.ntp.org");
    started = millis();
    while (time(nullptr) < 100000 && millis() - started < 10000) {
      delay(200);
    }
    timeValid = time(nullptr) >= 100000;
    logLine(timeValid ? "INFO" : "WARN", timeValid ? "NTP synced" : "NTP not synced");
    if (!signIn()) {
      logLine("ERROR", "firebase sign-in failed at boot");
    }
  } else {
    logLine("ERROR", "wifi failed");
  }

  show(1, "TAP CARD");
  logLine("INFO", "ready");
}

unsigned long lastCommandPoll = 0;
unsigned long lastFlush = 0;

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastReconnect = 0;
    if (millis() - lastReconnect > 5000) {
      lastReconnect = millis();
      logLine("WARN", "wifi lost, reconnecting...");
      WiFi.reconnect();
    }
  }

  if (ensureOnline() && millis() - lastCommandPoll > COMMAND_POLL_MS && !processingScan) {
    lastCommandPoll = millis();
    pollEnrollCommand();
  }

  if (millis() - lastFlush > 2000) {
    lastFlush = millis();
    flushQueue();
  }

  if (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial()) {
    return;
  }

  String tagUid = uidToString(mfrc522.uid.uidByte, mfrc522.uid.size);
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
  processCard(tagUid);

  show(1, "TAP CARD");
}