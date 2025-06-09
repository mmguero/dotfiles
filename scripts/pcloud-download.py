#!/usr/bin/env python3

import requests
import re
import json

# Step 1: Fetch the HTML from pCloud's installer page
url = "https://www.pcloud.com/how-to-install-pcloud-drive-linux.html?download=electron-64"
html = requests.get(url).text

# Step 2: Extract the `driveDLcode` JavaScript object
match = re.search(r'var driveDLcode\s*=\s*({.*?});', html, re.DOTALL)
if not match:
    raise ValueError("Could not find driveDLcode in page")

# Step 3: Convert JS-style dict to JSON
# - Replace single quotes with double quotes
# - Escape problematic characters
js_object = match.group(1)
json_like = re.sub(r"'", '"', js_object)

# Step 4: Parse it as JSON
drive_dlcode = json.loads(json_like)

# Step 5: Get the dlcode for Electron (64-bit AppImage)
dlcode = drive_dlcode.get("Electron")
if not dlcode:
    raise ValueError("Electron key not found in driveDLcode")

# Step 6: Use the pCloud API to get the real download URL
info = requests.get(f"https://api.pcloud.com/getpublinkdownload?code={dlcode}").json()
host = info["hosts"][0]
path = info["path"]
download_url = f"https://{host}{path}"

# Step 7: Download the actual AppImage
print(f"🔽 Downloading from: {download_url}")
r = requests.get(download_url, stream=True)
with open("pcloud-electron-x64.AppImage", "wb") as f:
    for chunk in r.iter_content(chunk_size=8192):
        f.write(chunk)

print("✅ Downloaded latest pCloud Electron AppImage")
