---
title: "Attendor — RFID School Attendance System"
geometry: margin=1in
fontsize: 11pt
---

# Attendor — RFID School Attendance System

Attendor is an automated school attendance system built on an **ESP32 + RC522 RFID reader with an OLED 128x64 display** (the hardware at school) and a **web dashboard** (the software everyone logs into). It replaces paper registers with card taps, and it is designed so that *anyone* — students, teachers, or the school owner — can understand how it works.

## 1. What Attendor does (for everyone)

- **Students tap an RFID card** at their classroom reader. One tap counts for both *arrival* and *attendance*.
- **The reader's OLED screen reacts instantly** — it shows the student's name and the result ("Present: Rahul", "Card bound", or an error) right on the device.
- **Attendance happens twice a day**: Morning window 08:00–08:20 and afternoon window 14:40–15:00, Monday to Saturday (Sunday closed). The school can change these times for any class.
- **Once every student in the class has tapped**, the attendance window closes automatically. A teacher may also close it early.
- **Students join a class using an entry code** the school gives out — they register online in under a minute.
- **Teachers see a live roster** of who is present or absent for the day, and can bind a student to a physical card with one click.
- **Students can view their own attendance history** anywhere, anytime.

## 2. Who uses it

| Role | What they can do |
|------|------------------|
| **School admin** | Create classes, add teachers, add ESP32 devices, see entry codes, manage the school |
| **Teacher** | Live present/absent roster, close a window, assign cards to students |
| **Student** | Register with an entry code, view own attendance history |
| **ESP32 device** | Detects card taps, shows the student's name and result on the OLED screen, queues scans offline |

## 3. How it works under the hood (for technical people)

### The pipeline

```
Student taps card
   └─▶ ESP32 + RC522 reads tag UID
        ├─▶ OLED 128x64 shows "Welcome, scanning..."
        └─▶ Firebase Realtime Database  (devices/<id>/scans)
             └─▶ Python worker (polls Firebase, runs on Render)
                  ├─▶ Validates: tag→student, time window, session state
                  ├─▶ Writes attendance + entry logs
                  └─▶ Writes pass/fail back → OLED shows name + result
Student sees it in the dashboard
```

### Components

| Component | Technology | Where it runs |
|-----------|-----------|---------------|
| Reader hardware | ESP32 + RC522 (13.56 MHz) + OLED 128x64 (SSD1306, I2C) | In the classroom |
| Device firmware | Arduino (C++) — Firebase REST, offline queue, OLED UI | On the ESP32 |
| Backend processor | Python 3 + FastAPI + `firebase-admin` SDK | Render (cloud); background poller + live log web UI |
| Frontend (web) | Flutter web | Firebase Hosting |
| Authentication | Firebase Auth (email/password for all roles) | Firebase |
| Database | Firebase Realtime Database | Firebase |

### Key design decisions

- **Tag UID = the student key.** A card is bound to a student the first time the teacher assigns it; the tag UID itself becomes the lookup key.
- **Device = one class.** Each ESP32 is permanently attached to one class, so a tap unambiguously counts for that class.
- **Offline-safe.** If the school internet drops, the ESP32 saves scans in local memory and re-sends them when connected (duplicates are ignored).
- **On-device feedback.** The OLED 128x64 display confirms every tap: a green "Present" screen, a card-binding screen, or a red error screen (unknown tag, closed session, off hours).
- **Self-registration.** Students register with an entry code; a worker verifies the code and adds them to the correct class automatically.

## 4. Data model (Firebase Realtime Database)

```
registrationCodes/<code>          public lookup: code → class
pendingRegistrations/<uid>        student waiting to be added
userMeta/<uid>                    role (admin/teacher/student)
schools/<schoolId>/
  profile/                        name, timezone
  admins/<uid>                    true
  teachers/<uid>/                 name, email, classId
  students/<uid>/                 name, classId, tagUid ("bind-able")
  classes/<classId>/              name, teacherUid, deviceId, entryCode,
                                  windows (am/pm), activeDays, sessions
  devices/<deviceId>/             label, classId, scans, responses,
                                  enrollCommand
  attendance/<classId>/<date>/<uid>/am|pm   {present, firstScan, lastScan}
  entryLogs/<classId>/<date>/<logId>        audit trail of every tap
_meta/processedScans/<deviceId>            poller cursor
```

## 5. Security model

- Firebase **security rules** restrict read/write per role: admins manage everything, teachers read/write only their own class, students read only their own records, and an ESP32 may only write to its **own** device node.
- Critical writes (attendance, card binding, registration) are performed by the **Python worker**, which uses the Firebase Admin SDK and bypasses client rules — clients can never forge attendance.
- Entry codes are single-use: once a student registers with a code, it is consumed.

## 6. Deployment checklist

1. Create a Firebase project; enable email/password auth, Realtime Database, and Hosting.
2. Deploy the security rules: `firebase deploy --only database`.
3. Run `bootstrap_school.py` (creates the school + admin) and `create_device.py` (creates an ESP32 login) locally with a service-account key.
4. Deploy the Python worker on Render (FastAPI + poller). Its URL shows live scan logs.
5. Build the Flutter dashboard with `--dart-define` Firebase config and deploy to Firebase Hosting.
6. Flash each ESP32 with its device credentials; mount it at the classroom reader.

## 7. Current status

The system is complete end to end:

| Piece | Status |
|-------|--------|
| Firebase security rules | Complete |
| Python worker (scan processing, windows, card binding, log UI) | Complete |
| Flutter dashboard (admin / teacher / student) | Complete |
| ESP32 firmware (RC522 + OLED 128x64, Firebase REST, offline queue) | Complete |
| Live log web UI | Complete |

Attendor is committed to git and verified (`flutter analyze` clean, unit tests pass). The remaining work is operational, not developmental: creating the school and device registers, deploying to Firebase/Render, and programming the classroom readers.