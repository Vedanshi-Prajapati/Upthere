import subprocess
import time
import os

OUTPUT_DIR = "screenshots"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# List of (tab, scene, name_prefix)
items = [
    ("home", "clearDay", "home_clearDay"),
    ("home", "clearNight", "home_clearNight"),
    ("home", "cloudy", "home_cloudy"),
    ("home", "fog", "home_fog"),
    ("home", "rain", "home_rain"),
    ("home", "snow", "home_snow"),
    ("forecast", "clearDay", "forecast_clearDay"),
    ("settings", "clearDay", "settings_clearDay")
]

appearances = ["light", "dark"]

for tab, scene, prefix in items:
    for appearance in appearances:
        print(f"Capturing {prefix}_{appearance}...")
        subprocess.run(["xcrun", "simctl", "ui", "booted", "appearance", appearance], check=True)
        subprocess.run(["xcrun", "simctl", "terminate", "booted", "com.vedanshi.upthereapp"])
        time.sleep(1.0)

        cmd = [
            "xcrun", "simctl", "launch", "booted", "com.vedanshi.upthereapp",
            "-useMockRepository", "-disableSplash", "-disablePermission",
            "-initialTab", tab,
            "-skyScene", scene
        ]
        subprocess.run(cmd, check=True)
        time.sleep(2.5)

        filename = f"{prefix}_{appearance}.png"
        filepath = os.path.join(OUTPUT_DIR, filename)
        subprocess.run(["xcrun", "simctl", "io", "booted", "screenshot", filepath], check=True)
        size = os.path.getsize(filepath)
        print(f"Saved {filepath} ({size} bytes)")

print("All screenshots captured successfully!")
