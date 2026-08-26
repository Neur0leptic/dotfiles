#!/usr/bin/env python3
import os
import secrets
import string
import sys

from pykeepass import PyKeePass


def main():
    db = os.environ.get("KPASS_DB")
    pwd = os.environ.get("KPASS_PASSWORD")
    if not db or not pwd:
        print("E: KPASS_DB and KPASS_PASSWORD must be set", file=sys.stderr)
        sys.exit(1)

    if len(sys.argv) < 2:
        print("Usage: kp.py <cmd> [args]", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    kp = PyKeePass(db, password=pwd)

    if cmd == "ls":
        for entry in sorted(kp.entries, key=lambda item: item.title or ""):
            if not entry.is_a_history_entry and entry.title:
                print(entry.title)

    elif cmd == "show":
        entry = kp.find_entries(title=" ".join(sys.argv[2:]), first=True)
        if not entry:
            sys.exit(1)
        print(f"Title: {entry.title}")
        print(f"UserName: {entry.username or ''}")
        print(f"Password: {entry.password or ''}")
        print(f"URL: {entry.url or ''}")
        print(f"Notes: {entry.notes or ''}")

    elif cmd == "pass":
        entry = kp.find_entries(title=" ".join(sys.argv[2:]), first=True)
        if entry and entry.password:
            sys.stdout.write(entry.password)

    elif cmd == "search":
        for entry in kp.find_entries(title=" ".join(sys.argv[2:]), regex=True, flags="i") or []:
            print(entry.title)

    elif cmd == "add":
        title = sys.argv[2] if len(sys.argv) > 2 else ""
        args = {"username": None, "password": None, "url": None, "notes": None}
        index = 3
        while index < len(sys.argv):
            arg = sys.argv[index]
            if arg in ("-u", "--username") and index + 1 < len(sys.argv):
                args["username"] = sys.argv[index + 1]
                index += 2
            elif arg in ("-p", "--password") and index + 1 < len(sys.argv):
                args["password"] = sys.argv[index + 1]
                index += 2
            elif arg in ("-l", "--url") and index + 1 < len(sys.argv):
                args["url"] = sys.argv[index + 1]
                index += 2
            elif arg in ("-n", "--notes") and index + 1 < len(sys.argv):
                args["notes"] = sys.argv[index + 1]
                index += 2
            elif arg in ("-g", "--generate"):
                has_length = index + 1 < len(sys.argv) and sys.argv[index + 1].isdigit()
                length = int(sys.argv[index + 1]) if has_length else 24
                chars = string.ascii_letters + string.digits + "!@#$%^&*"
                args["password"] = "".join(secrets.choice(chars) for _ in range(length))
                index += 2 if has_length else 1
            else:
                index += 1
        if title:
            kp.add_entry(kp.root_group, title=title, **args)
            kp.save()

    elif cmd == "rm":
        entry = kp.find_entries(title=" ".join(sys.argv[2:]), first=True)
        if entry:
            entry.delete()
            kp.save()

    elif cmd == "gen":
        length = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 24
        chars = string.ascii_letters + string.digits + "!@#$%^&*"
        sys.stdout.write("".join(secrets.choice(chars) for _ in range(length)))

    elif cmd == "apply":
        entry = kp.find_entries(title=" ".join(sys.argv[2:]), first=True)
        if not entry:
            sys.exit(1)
        for line in sys.stdin:
            line = line.rstrip("\n\r")
            if not line or ": " not in line:
                continue
            key, value = line.split(": ", 1)
            key = key.lower()
            if key == "title" and value:
                entry.title = value
            elif key == "username":
                entry.username = value or ""
            elif key == "password" and value:
                entry.password = value
            elif key == "url":
                entry.url = value or ""
            elif key == "notes":
                entry.notes = value or ""
        kp.save()


if __name__ == "__main__":
    main()
