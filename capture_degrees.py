import subprocess
import re
import time
import os
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "RFCY81RV9YH"
SCREENSHOT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Screenshots")

def adb(*args):
    cmd = [ADB, "-s", DEVICE] + list(args)
    result = subprocess.run(cmd, capture_output=True, timeout=30)
    return result

def tap(x, y):
    adb("shell", "input", "tap", str(x), str(y))

def swipe(y1, y2, ms="250"):
    adb("shell", "input", "swipe", "540", str(y1), "540", str(y2), ms)

def back():
    adb("shell", "input", "keyevent", "KEYCODE_BACK")

def dump_ui():
    adb("shell", "uiautomator", "dump", "/sdcard/ui_dump.xml")
    adb("pull", "/sdcard/ui_dump.xml", "ui_dump_current.xml")
    try:
        return ET.parse("ui_dump_current.xml")
    except:
        return None

def parse_bounds(bounds_str):
    m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds_str)
    if m:
        x1, y1, x2, y2 = map(int, m.groups())
        return (x1 + x2) // 2, (y1 + y2) // 2
    return None

def find_degree_cards(tree):
    cards = []
    if tree is None:
        return cards
    for node in tree.getroot().iter("node"):
        desc = node.get("content-desc", "")
        if node.get("clickable") == "true" and "JS" in desc:
            m = re.search(r'(JSSU\d{2}|JS\d{4})', desc)
            if m:
                center = parse_bounds(node.get("bounds", ""))
                if center:
                    title = desc.split('\n')[0]
                    cards.append({"code": m.group(0), "title": title, "center": center})
    return cards

def capture_screenshot(code):
    """Fast scroll to bottom and capture."""
    time.sleep(1.0)
    # Fixed 6 swipes to reach bottom (zoomed-out layout needs bigger scrolls)
    for _ in range(6):
        swipe(2000, 300)
        time.sleep(0.4)
    # Extra slow swipe to ensure we hit the very bottom
    adb("shell", "input", "swipe", "540", "2000", "540", "300", "600")
    time.sleep(0.3)
    # Capture using exec-out directly to file (faster than screencap+pull)
    filepath = os.path.join(SCREENSHOT_DIR, f"{code}.jpg")
    with open(filepath, "wb") as f:
        result = subprocess.run(
            [ADB, "-s", DEVICE, "exec-out", "screencap", "-p"],
            stdout=f, timeout=15
        )
    size = os.path.getsize(filepath) if os.path.exists(filepath) else 0
    print(f"  Captured {code}.jpg ({size} bytes)", flush=True)
    back()
    time.sleep(1.0)

def main():
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    captured = set()
    for f in os.listdir(SCREENSHOT_DIR):
        m = re.match(r'(JSSU\d{2}|JS\d{4})\.jpg', f)
        if m:
            captured.add(m.group(1))
    print(f"Already captured {len(captured)}: {sorted(captured)}", flush=True)

    consecutive_empty = 0
    max_rounds = 80

    for round_num in range(max_rounds):
        tree = dump_ui()
        cards = find_degree_cards(tree)
        new_cards = [c for c in cards if c["code"] not in captured]

        if new_cards:
            consecutive_empty = 0
            for card in new_cards:
                code = card["code"]
                if code in captured:
                    continue
                print(f"[{len(captured)+1}] {code} - {card['title']}", flush=True)

                # Use coordinates from the current dump directly (no re-dump)
                cx, cy = card["center"]
                tap(cx, cy)
                capture_screenshot(code)
                captured.add(code)

                # Re-dump to get fresh coordinates for remaining cards
                tree = dump_ui()
                fresh_cards = find_degree_cards(tree)
                fresh_map = {c["code"]: c for c in fresh_cards}
                # Update remaining new_cards with fresh coordinates
                for nc in new_cards:
                    if nc["code"] in fresh_map and nc["code"] not in captured:
                        nc["center"] = fresh_map[nc["code"]]["center"]
        else:
            consecutive_empty += 1
            # Scroll down one card at a time (~600px) to avoid skipping cards
            swipe(1100, 500)
            time.sleep(0.6)
            if consecutive_empty >= 15:
                print("Reached end of list or stuck.", flush=True)
                break

    print(f"\nDone! Captured {len(captured)} degrees: {sorted(captured)}", flush=True)

if __name__ == "__main__":
    main()