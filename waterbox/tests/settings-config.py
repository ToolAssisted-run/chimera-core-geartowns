#!/usr/bin/env python3
# Writes the window's settings for a frontend run: empty but for the firmware
# given, remembered as the Firmware window remembers a file chosen by hand
# (keyed under this core's name). The run's machine settings are its
# project's: run-frontend.sh makes one with them.
#
# Usage: settings-config.py <output settings> <firmware JSON {"<id>": "<path>"}>
import json
import sys

out = {"cores.chosenFirmware": json.dumps({"Geartowns": json.loads(sys.argv[2])})}
json.dump(out, open(sys.argv[1], "w"), indent=2)
