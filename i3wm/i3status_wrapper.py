#!/usr/bin/env python3
import sys, json, re

for line in sys.stdin:
    if line.strip().startswith('{'):
        j = json.loads(line)
        for block in j:
            # WiFi icon
            if block.get('name') == 'wireless _first_':
                quality = block.get('full_text')
                if "%" in quality:
                    try:
                        percent = int(quality.split()[1].replace("(", "").replace("%", ""))
                        if percent > 70:
                            icon = ""
                        elif percent > 40:
                            icon = "直"
                        else:
                            icon = "睊"
                        ssid = quality.split()[0]  # ambil SSID
                        block['full_text'] = f"{icon} {ssid}"
                    except:
                        block['full_text'] = "睊 no wifi"

            # Battery icon
            if block.get('name') == 'battery all':
                text = block.get('full_text')
                percent_match = re.search(r'(\d+)%', text)
                if percent_match:
                    percent = int(percent_match.group(1))
                    if "Charging" in text:
                        if percent >= 95:
                            icon = ""
                        else:
                            icon = ""
                    else:
                        if percent > 80:
                            icon = ""
                        elif percent > 60:
                            icon = ""
                        elif percent > 40:
                            icon = ""
                        elif percent > 20:
                            icon = ""
                        else:
                            icon = ""
                    block['full_text'] = f"{icon} {percent}%"

            # Volume icon
            if block.get('name') == 'volume master':
                text = block.get('full_text')
                vol_match = re.search(r'(\d+)%', text)
                if "off" in text.lower():
                    icon = "婢"
                    block['full_text'] = f"{icon} mute"
                elif vol_match:
                    percent = int(vol_match.group(1))
                    if percent == 0:
                        icon = "婢"
                    elif percent < 30:
                        icon = ""
                    elif percent < 70:
                        icon = ""
                    else:
                        icon = ""
                    block['full_text'] = f"{icon} {percent}%"
        sys.stdout.write(json.dumps(j) + ",\n")
        sys.stdout.flush()
    else:
        sys.stdout.write(line)
        sys.stdout.flush()
