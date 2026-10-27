#!/usr/bin/env python3
"""Emulator smoke test for the release APK (run by .github/workflows/android-qa.yml).

Installs the APK, signs in with a fresh email account, checks the no-plan lock
screen, starts the free trial for that account through the live API, then walks
setup and every tab. Screenshots land in qa-out/, and any crash of the app
(FATAL EXCEPTION / ANR in logcat) fails the run.

    python3 scripts/qa.py <apk> <email> <password> <id_token>
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET

PKG = "com.salahalarm.android"
OUT = "qa-out"
API = "https://salahalarm.com"
os.makedirs(OUT, exist_ok=True)
apk, email, password, id_token = sys.argv[1:5]
shots = []
problems = []


def adb(*args, check=True):
    return subprocess.run(["adb", *args], capture_output=True, text=True, check=check).stdout


def shot(name):
    path = f"{OUT}/{len(shots) + 1:02d}-{name}.png"
    with open(path, "wb") as f:
        f.write(subprocess.run(["adb", "exec-out", "screencap", "-p"], capture_output=True, check=True).stdout)
    shots.append(path)
    print("screenshot", path, "|", " / ".join(t for t in (n.get("text") for n in nodes()) if t)[:300])


def nodes():
    for _ in range(3):
        adb("shell", "uiautomator", "dump", "/sdcard/ui.xml", check=False)
        xml = adb("exec-out", "cat", "/sdcard/ui.xml", check=False)
        if xml.strip().startswith("<?xml"):
            return list(ET.fromstring(xml).iter("node"))
        time.sleep(1)
    return []


def find(pattern, clickable_only=False):
    rx = re.compile(pattern, re.I)
    for n in nodes():
        label = n.get("text") or n.get("content-desc") or ""
        if label and rx.search(label) and (not clickable_only or n.get("clickable") == "true"):
            return n
    return None


def tap(node):
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds")))
    adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
    time.sleep(1.5)


def tap_text(pattern, wait=10):
    end = time.time() + wait
    while time.time() < end:
        n = find(pattern)
        if n is not None:
            tap(n)
            return True
        time.sleep(1)
    return False


def type_into(index, text):
    """Types into the index-th text field on screen (Compose labels are not reliable targets)."""
    fields = [n for n in nodes() if n.get("class") == "android.widget.EditText"]
    if len(fields) <= index:
        problems.append(f"text field {index} not found ({len(fields)} on screen)")
        return
    tap(fields[index])
    adb("shell", "input", "text", text.replace("@", "\\@").replace(" ", "%s"))
    adb("shell", "input", "keyevent", "111")  # hide the keyboard so the next field is visible
    time.sleep(1)


def wait_for(pattern, wait=30):
    end = time.time() + wait
    while time.time() < end:
        if find(pattern) is not None:
            return True
        time.sleep(1.5)
    return False


def launch():
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1", check=False)
    time.sleep(3)


def back_to_app():
    # The locked screen opens the website once; come back to the app.
    launch()


def grant(*perms):
    for p in perms:
        adb("shell", "pm", "grant", PKG, p, check=False)


adb("logcat", "-c")
adb("install", "-r", "-g", apk)
grant("android.permission.POST_NOTIFICATIONS", "android.permission.ACCESS_FINE_LOCATION", "android.permission.ACCESS_COARSE_LOCATION")
adb("shell", "appops", "set", PKG, "SCHEDULE_EXACT_ALARM", "allow", check=False)
launch()
time.sleep(4)
shot("login")

if not tap_text(r"sign in with email"):
    problems.append("login: 'Sign in with email' not found")
type_into(0, email)
type_into(1, password)
shot("login-filled")
if not tap_text(r"^sign in$"):
    problems.append("login: 'sign in' button not found")
time.sleep(8)
back_to_app()
if wait_for(r"choose a plan to start|choose a plan", 30):
    shot("locked-no-plan")
else:
    problems.append("locked screen did not appear for an account without a plan")
    shot("after-sign-in")

# Start the free trial for this account through the live site, then "I've already paid".
req = urllib.request.Request(f"{API}/api/trial", method="POST", data=b"{}", headers={
    "authorization": f"Bearer {id_token}", "content-type": "application/json", "user-agent": "SalahAlarm-QA",
})
print("trial:", urllib.request.urlopen(req).read().decode()[:200])
tap_text(r"already paid")
time.sleep(6)
shot("after-trial")

# Setup checklist, then the main tabs.
for _ in range(6):
    if find(r"^home$") is not None:
        break
    if not (tap_text(r"^continue$|^done$|^next$|^get started$|^skip$", wait=4)):
        adb("shell", "input", "keyevent", "4")
        time.sleep(2)
    shot("setup")
for tab in ["Home", "Prayers", "Lock", "Quran", "Profile"]:
    if tap_text(rf"^{tab}$", wait=8):
        time.sleep(3)
        shot(tab.lower())
    else:
        problems.append(f"tab not found: {tab}")

# A Quran surah, if the list loaded.
if tap_text(r"^quran$", wait=5) and tap_text(r"al-fatihah|fatiha", wait=15):
    time.sleep(4)
    shot("quran-reader")
    adb("shell", "input", "keyevent", "4")

log = adb("logcat", "-d", "-v", "brief")
with open(f"{OUT}/logcat.txt", "w") as f:
    f.write(log)
crashes = [line for line in log.splitlines() if ("FATAL EXCEPTION" in line or "ANR in " + PKG in line)]
crash_ctx = re.findall(r"FATAL EXCEPTION.*?(?:\n.*?){0,25}", log)
if crashes:
    problems.append("app crashed: " + " | ".join(crash_ctx[:2]))

summary = {"screenshots": len(shots), "problems": problems}
with open(f"{OUT}/summary.json", "w") as f:
    json.dump(summary, f, indent=2)
print(json.dumps(summary, indent=2))
sys.exit(1 if problems else 0)
