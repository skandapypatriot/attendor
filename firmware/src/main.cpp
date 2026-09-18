#include <Arduino.h>

#if __has_include("secrets.h")
#include "secrets.h"
#endif

#if defined(ESP8266)
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <LittleFS.h>
#else
#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#endif

#include <WiFiClientSecure.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>

#if OLED_ENABLED
#include <Wire.h>
#include <U8g2lib.h>
#include <qrcode.h>
#endif

#include "config.h"

#define SS_PIN RC522_SS_PIN
#define RST_PIN RC522_RST_PIN

MFRC522 mfrc522(SS_PIN, RST_PIN);
WiFiClientSecure secureClient;

#if OLED_ENABLED
U8G2_SSD1306_128X64_NONAME_F_HW_I2C display(U8G2_R0, /* reset=*/ U8X8_PIN_NONE, /* clock=*/ OLED_SCL_PIN, /* data=*/ OLED_SDA_PIN);
bool oledPresent = false;
#endif

String token = "";
unsigned long tokenAt = 0;

bool pendingEnroll = false;
bool timeValid = false;
bool processingScan = false;

String MAC_ID = "";
String linkedSchool = "";
String linkedClass = "";
bool linked = false;

struct HttpResult {
  int code;
  String body;
};

#if defined(ESP8266)
bool storageBegin() { return LittleFS.begin(); }
String storageRead() {
  File f = LittleFS.open("/queue.json", "r");
  if (!f) return "";
  String s = f.readString();
  f.close();
  return s;
}
bool storageWrite(const String &s) {
  File f = LittleFS.open("/queue.json", "w");
  if (!f) return false;
  size_t written = f.print(s);
  f.close();
  return written == s.length();
}

String linkRead() {
  File f = LittleFS.open("/link.json", "r");
  if (!f) return "";
  String s = f.readString();
  f.close();
  return s;
}

bool linkWrite(const String &s) {
  File f = LittleFS.open("/link.json", "w");
  if (!f) return false;
  size_t written = f.print(s);
  f.close();
  return written == s.length();
}
#else
Preferences storage;
bool storageBegin() { return storage.begin("attendor", false); }
String storageRead() { return storage.getString("queue", ""); }
bool storageWrite(const String &s) { return storage.putString("queue", s) == (s.length() + 1); }
#endif

String devicePath() {
  return "devices/" + MAC_ID;
}

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
    String url = String(FIREBASE_DATABASE_URL) + "/" + devicePath() + "/logs.json?auth=" + token;
    HTTPClient http;
    http.begin(secureClient, url);
    http.addHeader("Content-Type", "application/json");
    http.POST(body);
    http.end();
  }
#endif
}

#if OLED_ENABLED

// --- Drawing helpers ---
void oledDrawCheck(int x, int y) {
  display.drawFrame(x, y, 10, 10);
  display.drawLine(x+2, y+5, x+4, y+8);
  display.drawLine(x+4, y+8, x+8, y+2);
}

void oledDrawX(int x, int y) {
  display.drawFrame(x, y, 10, 10);
  display.drawLine(x+2, y+2, x+8, y+8);
  display.drawLine(x+8, y+2, x+2, y+8);
}

void oledDrawCard(int x, int y) {
  display.drawFrame(x, y, 20, 14);
  display.drawHLine(x+2, y+5, 8);
  display.drawHLine(x+2, y+8, 12);
  display.drawHLine(x+2, y+11, 6);
}

void oledProgressBar(int x, int y, int w, int h, int percent) {
  display.drawFrame(x, y, w, h);
  int fill = (w - 2) * percent / 100;
  if (fill > 0) display.drawBox(x+1, y+1, fill, h-2);
}

void oledStatusBar(const String &left, const String &right) {
  display.setFont(u8g2_font_5x7_tr);
  display.drawStr(0, 10, left.c_str());
  int rw = display.getStrWidth(right.c_str());
  display.drawStr(128 - rw, 10, right.c_str());
  display.drawHLine(0, 12, 128);
}

// --- Screen functions ---
void oledBootScreen() {
  if (!oledPresent) return;
  display.clearDisplay();
  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(28, 16, "ATTENDOR");
  display.setFont(u8g2_font_5x7_tr);
  display.drawStr(36, 28, "booting...");
  oledProgressBar(14, 40, 100, 8, 0);
  display.display();
}

void oledBootStep(int step, int total, const String &label, bool ok) {
  if (!oledPresent) return;
  int y = 14 + step * 7;
  if (y > 54) y = 54;
  display.setFont(u8g2_font_5x7_tr);
  if (ok) oledDrawCheck(0, y - 6);
  else oledDrawX(0, y - 6);
  display.drawStr(14, y, label.c_str());
  oledProgressBar(14, 56, 100, 8, (step + 1) * 100 / total);
  display.display();
}

void oledReady(const String &className, const String &mac) {
  if (!oledPresent) { logLine("INFO", "TAP CARD"); return; }
  display.clearDisplay();
  oledStatusBar("READY", className.length() ? className : "UNLINKED");
  display.setFont(u8g2_font_7x14B_tf);
  oledDrawCard(4, 20);
  display.drawStr(30, 32, "TAP");
  display.drawStr(30, 46, "CARD");
  display.setFont(u8g2_font_4x6_tr);
  display.drawStr(0, 64, mac.c_str());
  display.display();
}

void oledPairQR() {
  // QR drawn separately by showPairQR
}

void oledScanning(const String &uid) {
  if (!oledPresent) { logLine("INFO", "SCANNING " + uid); return; }
  display.clearDisplay();
  oledStatusBar("SCANNING", "");
  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(20, 36, "Processing...");
  display.setFont(u8g2_font_4x6_tr);
  if (uid.length()) display.drawStr(0, 52, uid.c_str());
  display.display();
}

void oledResult(bool ok, const String &title, const String &msg) {
  if (!oledPresent) { logLine(ok ? "INFO" : "WARN", title + " " + msg); return; }
  display.clearDisplay();
  oledStatusBar(ok ? "OK" : "FAIL", "");
  if (ok) oledDrawCheck(50, 18);
  else oledDrawX(50, 18);
  display.setFont(u8g2_font_7x14B_tf);
  int tw = display.getStrWidth(title.c_str());
  display.drawStr((128 - tw) / 2, 44, title.c_str());
  display.setFont(u8g2_font_5x7_tr);
  if (msg.length()) {
    String trunc = msg.substring(0, 21);
    int mw = display.getStrWidth(trunc.c_str());
    display.drawStr((128 - mw) / 2, 56, trunc.c_str());
  }
  display.display();
}

void oledOffline(const String &uid) {
  if (!oledPresent) { logLine("WARN", "OFFLINE scan queued " + uid); return; }
  display.clearDisplay();
  oledStatusBar("OFFLINE", "");
  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(16, 36, "No Network");
  display.setFont(u8g2_font_5x7_tr);
  display.drawStr(20, 50, "Scan queued");
  display.setFont(u8g2_font_4x6_tr);
  if (uid.length()) display.drawStr(0, 62, uid.c_str());
  display.display();
}

void oledEnroll() {
  if (!oledPresent) { logLine("INFO", "ENROLL mode - scan student card"); return; }
  display.clearDisplay();
  oledStatusBar("ENROLL", "assign card");
  display.setFont(u8g2_font_7x14B_tf);
  oledDrawCard(50, 20);
  display.drawStr(0, 44, "Scan student");
  display.drawStr(0, 54, "card now");
  display.display();
}

void oledLinked(const String &classId) {
  if (!oledPresent) { logLine("INFO", "LINKED to class " + classId); return; }
  display.clearDisplay();
  oledStatusBar("LINKED", "");
  display.setFont(u8g2_font_7x14B_tf);
  oledDrawCheck(50, 16);
  display.setFont(u8g2_font_5x7_tr);
  int cw = display.getStrWidth(classId.c_str());
  display.drawStr((128 - cw) / 2, 40, classId.c_str());
  display.setFont(u8g2_font_4x6_tr);
  display.drawStr(0, 62, "Device ready");
  display.display();
}

void oledWifiLost() {
  if (!oledPresent) { logLine("WARN", "WiFi LOST, reconnecting"); return; }
  display.clearDisplay();
  oledStatusBar("WiFi", "reconnecting");
  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(16, 36, "WiFi LOST");
  display.setFont(u8g2_font_5x7_tr);
  display.drawStr(24, 52, "retrying...");
  display.display();
}

void show(int size, const String &line1, const String &line2 = "") {
  (void)size;
  if (!oledPresent) {
    logLine("INFO", line1 + (line2.length() ? " " + line2 : ""));
    return;
  }
  display.clearDisplay();
  display.setFont(u8g2_font_5x7_tr);
  display.drawStr(0, 12, line1.c_str());
  if (line2.length()) display.drawStr(0, 24, line2.c_str());
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

void queuePush(const String &body) {
  JsonDocument doc;
  deserializeJson(doc, storageRead());
  if (!doc.is<JsonArray>()) doc.to<JsonArray>();
  if (doc.as<JsonArray>().size() >= QUEUE_MAX_ENTRIES) {
    logLine("WARN", "queue full, scan dropped");
    return;
  }
  JsonDocument scan;
  if (deserializeJson(scan, body)) return;
  doc.as<JsonArray>().add(scan);
  String out;
  serializeJson(doc, out);
  storageWrite(out);
}

int queueSize() {
  JsonDocument doc;
  deserializeJson(doc, storageRead());
  return doc.is<JsonArray>() ? doc.as<JsonArray>().size() : 0;
}

bool queueFront(String &out) {
  JsonDocument doc;
  if (deserializeJson(doc, storageRead()) || !doc.is<JsonArray>()) return false;
  if (doc.as<JsonArray>().size() == 0) return false;
  serializeJson(doc.as<JsonArray>()[0], out);
  return true;
}

bool queuePop() {
  JsonDocument doc;
  if (deserializeJson(doc, storageRead()) || !doc.is<JsonArray>()) return false;
  if (doc.as<JsonArray>().size() == 0) return false;
  doc.as<JsonArray>().remove(0);
  String out;
  serializeJson(doc, out);
  return storageWrite(out);
}

void processCard(const String &tagUid) {
  processingScan = true;
  String type = pendingEnroll ? "enroll" : "attend";
  long ts = timeValid ? (long)time(nullptr) * 1000L : millis();
  logLine("INFO", String("card read type=") + type + " tag=" + tagUid);

  if (!ensureOnline()) {
    JsonDocument scan;
    scan["tagUid"] = tagUid;
    scan["ts"] = ts;
    scan["type"] = type;
    String body;
    serializeJson(scan, body);
    queuePush(body);
    logLine("WARN", "offline, scan queued");
#if OLED_ENABLED
    oledOffline(tagUid);
#endif
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
      urlWithAuth(devicePath() + "/scans"), body);
  if (r.code != 200) {
    logLine("ERROR", "scan push failed: " + String(r.code));
#if OLED_ENABLED
    oledResult(false, "SEND FAIL", "");
#endif
    processingScan = false;
    return;
  }
  JsonDocument result;
  deserializeJson(result, r.body);
  String scanId = result["name"] | "";

#if OLED_ENABLED
  oledScanning(tagUid);
#else
  show(1, "SCANNING...");
#endif
  String responsePath = devicePath() + "/responses/" + scanId;
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
#if OLED_ENABLED
      oledResult(ok, ok ? "PRESENT" : "NOT OK", msg);
#else
      show(ok ? 2 : 1, ok ? "PRESENT" : "NOT OK", msg.length() > 14 ? msg.substring(0, 14) : msg);
#endif
      break;
    }
    delay(200);
  }
  processingScan = false;
}

void pollEnrollCommand() {
  if (!ensureOnline() || !linked) return;
  HttpResult r = httpRequest("GET",
      urlWithAuth(devicePath() + "/enrollCommand"));
  bool active = (r.code == 200 && r.body != "null" && r.body.length() > 2);
  if (active && !pendingEnroll) {
    JsonDocument doc;
    deserializeJson(doc, r.body);
    String studentUid = doc["studentUid"] | "";
    pendingEnroll = studentUid.length() > 0;
    logLine("INFO", String("enroll command: bind card for ") +
                    (studentUid.length() ? studentUid : "student"));
#if OLED_ENABLED
    oledEnroll();
#else
    show(1, "ASSIGN CARD", "scan now");
#endif
  } else if (!active && pendingEnroll) {
    pendingEnroll = false;
    logLine("INFO", "enroll command done");
#if OLED_ENABLED
    oledReady(linkedClass, MAC_ID);
#else
    show(1, "TAP CARD");
#endif
  }
}

void flushQueue() {
  if (!ensureOnline()) return;
  String entry;
  if (!queueFront(entry)) return;
  HttpResult r = httpRequest("POST",
      urlWithAuth(devicePath() + "/scans"), entry);
  if (r.code == 200) {
    queuePop();
    logLine("INFO", "flushed queued scan (" + String(queueSize()) + " left)");
  } else {
    logLine("ERROR", "flush failed: " + String(r.code));
  }
}

void saveLink(const String &schoolId, const String &classId) {
  linked = true;
  linkedSchool = schoolId;
  linkedClass = classId;
  JsonDocument doc;
  doc["linked"] = true;
  doc["schoolId"] = schoolId;
  doc["classId"] = classId;
  String out;
  serializeJson(doc, out);
  linkWrite(out);
  logLine("INFO", "LINKED to school " + schoolId + " class " + classId);
#if OLED_ENABLED
  oledLinked(classId);
#endif
}

#if OLED_ENABLED
void showPairQr() {
  if (!oledPresent) { logLine("INFO", "PAIR CODE: " + MAC_ID); return; }
  QRCode qr;
  uint8_t buf[qrcode_getBufferSize(2)];
  qrcode_initText(&qr, buf, 2, ECC_LOW, MAC_ID.c_str());
  display.clearDisplay();
  display.setFont(u8g2_font_7x14B_tf);
  display.drawStr(20, 12, "UNLINKED");
  display.setFont(u8g2_font_4x6_tr);
  int mw = display.getStrWidth(MAC_ID.c_str());
  display.drawStr((128 - mw) / 2, 62, MAC_ID.c_str());
  const uint8_t scale = 2;
  int qrPx = qr.size * scale;
  int x0 = (128 - qrPx) / 2;
  int y0 = 16;
  for (uint8_t y = 0; y < qr.size; y++) {
    for (uint8_t x = 0; x < qr.size; x++) {
      if (qrcode_getModule(&qr, x, y)) {
        display.drawBox(x0 + x * scale, y0 + y * scale, scale, scale);
      }
    }
  }
  display.display();
}
#endif

void restoreLink() {
  String raw = linkRead();
  if (raw.length() == 0) return;
  JsonDocument doc;
  if (deserializeJson(doc, raw)) return;
  if (doc["linked"] | false) {
    linked = true;
    linkedSchool = doc["schoolId"] | "";
    linkedClass = doc["classId"] | "";
  }
}

void checkLink() {
  if (!ensureOnline()) return;
  HttpResult r = httpRequest("GET",
      urlWithAuth(devicePath()));
  if (r.code != 200 || r.body == "null" || r.body.length() <= 2) return;
  JsonDocument doc;
  deserializeJson(doc, r.body);
  String sid = doc["schoolId"] | "";
  String cid = doc["classId"] | "";
  if (sid.length() > 0 && cid.length() > 0 && !linked) {
    saveLink(sid, cid);
#if OLED_ENABLED
    oledLinked(linkedClass);
#endif
  }
}

void sendPresence() {
  if (!ensureOnline()) return;
  JsonDocument doc;
  doc["ts"] = (long)time(nullptr) * 1000L;
  doc["classId"] = linked ? linkedClass : "";
  doc["schoolId"] = linked ? linkedSchool : "";
  doc["linked"] = linked;
  String body;
  serializeJson(doc, body);
  HttpResult r = httpRequest("PUT",
      urlWithAuth(devicePath() + "/presence"), body);
  if (r.code != 200) logLine("WARN", "presence failed: " + String(r.code));
}

void setup() {
  Serial.begin(115200);
  secureClient.setInsecure();
  logLine("INFO", "Attendor device booting");

#if OLED_ENABLED
  const int BOOT_STEPS = 7;
  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  oledPresent = display.begin();
  if (!oledPresent) {
    logLine("WARN", "OLED not detected, running headless");
  }
  if (oledPresent) oledBootScreen();
#endif

  // Step 1: OLED
#if OLED_ENABLED
  if (oledPresent) {
    oledBootStep(0, BOOT_STEPS, "OLED", true);
    delay(300);
  } else {
    logLine("INFO", "Step 1/7 OLED  [SKIP]");
  }
#endif

  // Step 2: SPI / RFID
  #if defined(ESP8266)
  SPI.pins(RC522_SCK_PIN, RC522_MISO_PIN, RC522_MOSI_PIN, RC522_SS_PIN);
  SPI.begin();
  #else
  SPI.begin(RC522_SCK_PIN, RC522_MISO_PIN, RC522_MOSI_PIN, RC522_SS_PIN);
  #endif
  mfrc522.PCD_Init();
#if OLED_ENABLED
  if (oledPresent) { oledBootStep(1, BOOT_STEPS, "RFID", true); delay(300); }
#endif

  // Step 3: Storage
  bool storageOk = storageBegin();
  if (!storageOk) logLine("WARN", "storage init failed");
#if OLED_ENABLED
  if (oledPresent) { oledBootStep(2, BOOT_STEPS, "Storage", storageOk); delay(300); }
#endif

  // Step 4: WiFi
  show(1, "CONNECTING", "wifi");
  WiFi.mode(WIFI_STA);
  MAC_ID = WiFi.macAddress();
  MAC_ID.replace(":", "");
  MAC_ID.toUpperCase();
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  unsigned long started = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - started < 30000) {
    delay(250);
  }
  bool wifiOk = WiFi.status() == WL_CONNECTED;
#if OLED_ENABLED
  if (oledPresent) {
    oledBootStep(3, BOOT_STEPS, wifiOk ? WiFi.localIP().toString().c_str() : "WiFi FAILED", wifiOk);
    delay(500);
  }
#endif
  if (wifiOk) {
    logLine("INFO", "wifi connected: " + String(WiFi.localIP().toString()));

    // Step 5: NTP
    configTime(0, 0, "time.google.com", "pool.ntp.org");
    started = millis();
    while (time(nullptr) < 100000 && millis() - started < 10000) {
      delay(200);
    }
    timeValid = time(nullptr) >= 100000;
#if OLED_ENABLED
    if (oledPresent) { oledBootStep(4, BOOT_STEPS, timeValid ? "NTP synced" : "NTP FAILED", timeValid); delay(300); }
#endif
    logLine(timeValid ? "INFO" : "WARN", timeValid ? "NTP synced" : "NTP not synced");

    // Step 6: Firebase auth
    bool authOk = signIn();
#if OLED_ENABLED
    if (oledPresent) { oledBootStep(5, BOOT_STEPS, authOk ? "Firebase" : "Auth FAILED", authOk); delay(300); }
#endif
    if (!authOk) logLine("ERROR", "firebase sign-in failed at boot");
  } else {
    logLine("ERROR", "wifi failed");
  }

  if (queueSize() > 0) {
    logLine("WARN", String(queueSize()) + " queued scans from previous session");
  }

  // Step 7: Link check
  restoreLink();
  if (linked) {
    logLine("INFO", "device is LINKED to class " + linkedClass);
  } else {
    logLine("INFO", "UNLINKED - PAIR CODE: " + MAC_ID);
  }
#if OLED_ENABLED
  if (oledPresent) {
    oledBootStep(6, BOOT_STEPS, linked ? linkedClass.c_str() : "PAIR CODE", linked);
    delay(800);
  }
#endif

  // Final ready screen
#if OLED_ENABLED
  if (oledPresent) {
    if (linked) {
      oledLinked(linkedClass);
    } else {
      showPairQr();
    }
    delay(1500);
    oledReady(linkedClass, MAC_ID);
  } else {
    show(1, "TAP CARD");
  }
#else
  show(1, "TAP CARD");
#endif
  logLine("INFO", "ready");
}

unsigned long lastCommandPoll = 0;
unsigned long lastFlush = 0;
unsigned long lastPresence = 0;
unsigned long lastLinkCheck = 0;

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastReconnect = 0;
    if (millis() - lastReconnect > 5000) {
      lastReconnect = millis();
      logLine("WARN", "wifi lost, reconnecting...");
#if OLED_ENABLED
      oledWifiLost();
#endif
      WiFi.reconnect();
    }
  }

  if (ensureOnline() && linked && millis() - lastCommandPoll > COMMAND_POLL_MS && !processingScan) {
    lastCommandPoll = millis();
    pollEnrollCommand();
  }

  if (!linked) {
    if (millis() - lastPresence > 10000) {
      lastPresence = millis();
      sendPresence();
      if (millis() - lastLinkCheck > 30000 || lastLinkCheck == 0) {
        lastLinkCheck = millis();
        checkLink();
      }
    }
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

#if OLED_ENABLED
  oledReady(linkedClass, MAC_ID);
#else
  show(1, "TAP CARD");
#endif
}