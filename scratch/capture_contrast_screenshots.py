import subprocess
import time
import os

os.makedirs("docs/screenshots/contrast", exist_ok=True)

conditions = [
    ("clear-day", "clear"),
    ("partly-cloudy", "partlycloudy"),
    ("rain", "rain"),
    ("snow", "snow"),
    ("fog", "fog"),
    ("night", "night")
]

subprocess.run(["xcrun", "simctl", "ui", "booted", "appearance", "dark"], check=True)
subprocess.run(["xcrun", "simctl", "ui", "booted", "content_size", "large"], check=True)

for name, cond_arg in conditions:
    print(f"Capturing contrast screenshot for {name} ({cond_arg})...")
    subprocess.run(["xcrun", "simctl", "terminate", "booted", "com.vedanshi.upthereapp"])
    time.sleep(1.5)
    
    subprocess.run([
        "xcrun", "simctl", "launch", "booted", "com.vedanshi.upthereapp",
        "-useMockRepository", "-disableSplash", "-disablePermission",
        "-mockCondition", cond_arg,
        "-initialTab", "home"
    ], check=True)
    time.sleep(3.0)
    
    output_path = f"docs/screenshots/contrast/{name}.png"
    subprocess.run(["xcrun", "simctl", "io", "booted", "screenshot", output_path], check=True)
    size = os.path.getsize(output_path)
    print(f"Saved {output_path} ({size} bytes)")

print("All contrast screenshots captured successfully!")
