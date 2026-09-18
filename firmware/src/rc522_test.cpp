#include <Arduino.h>
#include <SPI.h>
#include <MFRC522.h>
#include "config.h"

#define SS_PIN RC522_SS_PIN
#define RST_PIN RC522_RST_PIN

MFRC522 mfrc522(SS_PIN, RST_PIN);

void printUid(byte *uid, byte uidSize) {
  Serial.print("UID (HEX) : ");
  for (byte i = 0; i < uidSize; i++) {
    if (uid[i] < 0x10) Serial.print("0");
    Serial.print(uid[i], HEX);
    if (i < uidSize - 1) Serial.print(" ");
  }
  Serial.println();

  Serial.print("UID (DEC) : ");
  for (byte i = 0; i < uidSize; i++) {
    Serial.print(uid[i], DEC);
    if (i < uidSize - 1) Serial.print(" ");
  }
  Serial.println();
}

MFRC522::PICC_Type getCardType(byte sak) {
  return mfrc522.PICC_GetType(sak);
}

const char *cardTypeName(MFRC522::PICC_Type type) {
  switch (type) {
    case MFRC522::PICC_TYPE_MIFARE_1K:      return "MIFARE 1K";
    case MFRC522::PICC_TYPE_MIFARE_4K:      return "MIFARE 4K";
    case MFRC522::PICC_TYPE_MIFARE_UL:      return "MIFARE Ultralight";
    case MFRC522::PICC_TYPE_MIFARE_MINI:    return "MIFARE Mini";
    case MFRC522::PICC_TYPE_TNP3XXX:        return "Topaz";
    case MFRC522::PICC_TYPE_ISO_14443_4:    return "ISO 14443-4";
    case MFRC522::PICC_TYPE_ISO_18092:      return "ISO 18092 (NFC)";
    default:                                return "Unknown";
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("========================================");
  Serial.println("  RC522 RFID Reader Test");
  Serial.println("========================================");

  #if defined(ESP8266)
  SPI.pins(RC522_SCK_PIN, RC522_MISO_PIN, RC522_MOSI_PIN, RC522_SS_PIN);
  SPI.begin();
  #else
  SPI.begin(RC522_SCK_PIN, RC522_MISO_PIN, RC522_MOSI_PIN, RC522_SS_PIN);
  #endif

  mfrc522.PCD_Init();

  byte v = mfrc522.PCD_ReadRegister(mfrc522.VersionReg);
  Serial.print("MFRC522 Version: 0x");
  Serial.println(v, HEX);
  if (v == 0x91) Serial.println("  -> v1.0");
  else if (v == 0x92) Serial.println("  -> v2.0");
  else Serial.println("  -> Unknown (check wiring!)");

  Serial.println();
  Serial.println("Place a card on the reader...");
  Serial.println("----------------------------------------");
}

void loop() {
  if (!mfrc522.PICC_IsNewCardPresent()) return;
  if (!mfrc522.PICC_ReadCardSerial()) return;

  Serial.println();
  Serial.println("--- Card Detected ---");

  printUid(mfrc522.uid.uidByte, mfrc522.uid.size);

  MFRC522::PICC_Type cardType = getCardType(mfrc522.uid.sak);
  Serial.print("Card Type : ");
  Serial.println(cardTypeName(cardType));
  Serial.print("SAK       : 0x");
  Serial.println(mfrc522.uid.sak, HEX);
  Serial.print("UID Size  : ");
  Serial.print(mfrc522.uid.size);
  Serial.println(" bytes");

  Serial.println("---------------------");
  Serial.println("Place a card on the reader...");

  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
}
