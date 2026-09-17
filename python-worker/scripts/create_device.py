import argparse
import json
import os
import secrets
import string
import time

from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, db, auth, exceptions

load_dotenv()


def get_service_account():
    sa = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if sa:
        return json.loads(sa), credentials.Certificate(json.loads(sa))
    path = os.environ["FIREBASE_SERVICE_ACCOUNT_PATH"]
    return json.loads(open(path).read()), credentials.Certificate(path)


def main():
    p = argparse.ArgumentParser(description="Create a Firebase Auth account for an ESP32 device")
    p.add_argument("--school-id", required=True)
    p.add_argument("--class-id", required=True)
    p.add_argument("--label", required=True)
    args = p.parse_args()

    sa, cred = get_service_account()
    firebase_admin.initialize_app(
        cred,
        {"databaseURL": os.environ["FIREBASE_DATABASE_URL"], "projectId": sa["project_id"]},
    )

    password = "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(16))
    email = f"device-{int(time.time() * 1000)}@attendor.in"
    try:
        device_user = auth.create_user(email=email, password=password)
        did = device_user.uid
    except exceptions.EmailAlreadyExistsError:
        print("collision; retry")

    db.reference(f"schools/{args.school_id}/devices/{did}").set(
        {
            "label": args.label,
            "schoolId": args.school_id,
            "classId": args.class_id,
            "authEmail": email,
            "createdAt": int(time.time() * 1000),
        }
    )
    db.reference(f"schools/{args.school_id}/classes/{args.class_id}/deviceId").set(did)

    print("Device created. Program these into the ESP32:")
    print(json.dumps(
        {
            "deviceId": did,
            "authEmail": email,
            "authPassword": password,
            "classId": args.class_id,
        },
        indent=2,
    ))


if __name__ == "__main__":
    main()