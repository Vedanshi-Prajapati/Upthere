import subprocess
import time
import sys

prefix = sys.argv[1] if len(sys.argv) > 1 else "before"
tabs = ["home", "forecast", "insights", "locations", "settings"]
modes = [
    ("light", "light", "large"),
    ("dark", "dark", "large"),
    ("a11y3", "dark", "accessibility-extra-large"),
]

for mode_name, appearance, content_size in modes:
    print(f"Setting appearance={appearance}, content_size={content_size}...")
    subprocess.run(["xcrun", "simctl", "ui", "booted", "appearance", appearance], check=True)
    subprocess.run(["xcrun", "simctl", "ui", "booted", "content_size", content_size], check=True)
    time.sleep(0.5)

    for tab in tabs:
        print(f"Capturing {prefix}-{tab}-{mode_name}...")
        subprocess.run(["xcrun", "simctl", "terminate", "booted", "com.vedanshi.upthereapp"], stderr=subprocess.DEVNULL)
        time.sleep(0.5)
        subprocess.run([
            "xcrun", "simctl", "launch", "booted", "com.vedanshi.upthereapp",
            "-useMockRepository", "-disableSplash", "-disablePermission",
            "-initialTab", tab
        ], check=True)
        time.sleep(3.5)
        output_path = f"docs/screenshots/hierarchy/{tab}-{prefix}-{mode_name}.png"
        subprocess.run(["xcrun", "simctl", "io", "booted", "screenshot", output_path], check=True)
        print(f"Saved {output_path}")

# Reset simulator settings
subprocess.run(["xcrun", "simctl", "ui", "booted", "appearance", "dark"], check=True)
subprocess.run(["xcrun", "simctl", "ui", "booted", "content_size", "large"], check=True)
print("Finished capturing screenshots.")
