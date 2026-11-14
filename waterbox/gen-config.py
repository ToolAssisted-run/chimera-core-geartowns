#!/usr/bin/env python3
# gen-config.py: writes waterbox/waterbox.config and waterbox/default_keybinds.json.
#
# The wire (the buttons, in order) is the console's buttons, two pads, the
# mouse's buttons and the keyboard, whose keys come from waterbox/keys.h, the
# same list cinterface.cpp is compiled from. The settings and the firmware
# are written out here so the two files are made the same way every time.
#
# Usage: python3 waterbox/gen-config.py [--check]
#   --check: write nothing; fail if either file is not what this would write.
import ast
import json
import os
import re
import sys

here = os.path.dirname(os.path.abspath(__file__))


def keys():
    text = open(os.path.join(here, "keys.h")).read()
    s = r'("(?:[^"\\]|\\.)*")'
    found = re.findall(r'KEY\(' + s + r', (GT_KEY_\w+), ' + s + ', ' + s + ', ' + s + r'\)', text)
    count = int(re.search(r'#define KEY_COUNT (\d+)', text).group(1))
    if len(found) != count:
        sys.exit(f"keys.h lists {len(found)} keys but says KEY_COUNT {count}")
    return [(ast.literal_eval(a), code, ast.literal_eval(m), ast.literal_eval(h), ast.literal_eval(b))
            for a, code, m, h, b in found]


PAD = ["Up", "Down", "Left", "Right", "Select", "Run", "A", "B", "C", "X", "Y", "Z", "Zoom"]
CONSOLE = ["Power", "Reset", "Next Floppy Disk", "Next CD"]
MOUSE = ["Mouse Left", "Mouse Right"]

# Geartowns' models, in its own order (src/common/types.h), the HC left out:
# upstream does not emulate it.
MODELS = ["model1_2", "1f_2f", "10f_20f", "cx", "ux", "ug", "hg", "hr", "ur",
          "me", "ma", "mx", "mf_fresh", "marty"]

# Which set of ROMs each model runs on: Geartowns' own first choice for it
# (BIOS_README.md, "Models and Sets"). SHA-1s are MAME's (fmtowns.cpp);
# the CRC32s beside them are the ones Geartowns' README and database list.
SETS = {
    "model12": {
        "models": ["model1_2"],
        "free": False,
        "files": {
            "FMT_SYS.ROM": (262144, "15D9CC705F3534FE97A2386E4D4848A1602CC534"),
            "FMT_DOS.ROM": (524288, "57FD146478226F7F215CAF63154C763A6D52165E"),
            "FMT_FNT.ROM": (262144, "FA5F7A18060AFA35678DCBDC3589A1455ABA26DC"),
            "FMT_DIC.ROM": (524288, "3959C4C6BE540252CABEA06847BCD408F1911CFB"),
        },
    },
    "free": {
        "models": ["model1_2"],
        "free": True,
        "files": {
            "FMT_SYS.ROM": (262144, "7E8B341137A017CA963EEADA66C70EBD21E3E549"),
            "FMT_DOS.ROM": (524288, "5A426EADEC4E518145FCE761AF571AF54C15267D"),
            "FMT_FNT.ROM": (262144, "7E99430B7804F12F1C35DFAF24AE27A5F13D9FE9"),
            "FMT_DIC.ROM": (524288, "13A184EC9E176371808938015111F8918CB4DF7D"),
        },
    },
    "ux": {
        "models": ["1f_2f", "10f_20f", "cx", "ux", "ug"],
        "files": {
            "FMT_SYS.ROM": (262144, "BE21404098B23465D24C4201A81C96AC01AFF7AB"),
            "FMT_DOS.ROM": (524288, "A7E97B25FF72B14121146137DB8B45D6C66AF2AE"),
            "FMT_FNT.ROM": (262144, "A216482EA3162F348FCF77FEA78E0B2E4288091A"),
            "FMT_DIC.ROM": (524288, "7564020DBA71DEEE27184824B84DBBBB7C72AA4E"),
        },
    },
    "hr": {
        "models": ["hg", "hr", "ur"],
        "files": {
            "FMT_SYS.ROM": (262144, "A4EBF2E247A8E15A5F1FF003B657BBE3A67203D8"),
            "FMT_DOS.ROM": (524288, "57FD146478226F7F215CAF63154C763A6D52165E"),
            "FMT_FNT.ROM": (262144, "A216482EA3162F348FCF77FEA78E0B2E4288091A"),
            "FMT_DIC.ROM": (524288, "7564020DBA71DEEE27184824B84DBBBB7C72AA4E"),
        },
    },
    "v10": {
        "models": ["me", "ma", "mx", "mf_fresh"],
        "files": {
            "FMT_SYS.ROM": (262144, "4CD51DE4FCA9BD7A3D91D09AD636FA6B47A41DF5"),
            "FMT_DOS.ROM": (524288, "57FD146478226F7F215CAF63154C763A6D52165E"),
            "FMT_FNT.ROM": (262144, "A216482EA3162F348FCF77FEA78E0B2E4288091A"),
            "FMT_DIC.ROM": (524288, "7564020DBA71DEEE27184824B84DBBBB7C72AA4E"),
            "FMT_F20.ROM": (524288, "1920711CB66340BB741A760DE187DE2F76040B8C"),
        },
    },
    "marty": {
        "models": ["marty"],
        "files": {
            "FMT_SYS.ROM": (262144, "7B1C97FA778986134104A6964C8FE13E3654F52E"),
            "FMT_DOS.ROM": (524288, "99CD51C5677288AD8EF711B4AC25D981FD586884"),
            "FMT_FNT.ROM": (262144, "A216482EA3162F348FCF77FEA78E0B2E4288091A"),
            "FMT_DIC.ROM": (524288, "7564020DBA71DEEE27184824B84DBBBB7C72AA4E"),
            "MAR_EX0.ROM": (524288, "1611FC4683DAB72E56A5D0EE0F757E5878900B31"),
            "MAR_EX1.ROM": (524288, "167D8AE47312CDAA30B8597144F60F54CE9F74D3"),
            "MAR_EX2.ROM": (524288, "B2ED2BA42B8132D139480484FE116BA7774E1604"),
            "MAR_EX3.ROM": (524288, "19B669AA6488BDAF8569E89B1B1067E51246A768"),
        },
    },
}

FILE_KEYS = {
    "FMT_SYS.ROM": "sys", "FMT_DOS.ROM": "dos", "FMT_FNT.ROM": "fnt", "FMT_DIC.ROM": "dic",
    "FMT_F20.ROM": "f20", "MAR_EX0.ROM": "ex0", "MAR_EX1.ROM": "ex1", "MAR_EX2.ROM": "ex2",
    "MAR_EX3.ROM": "ex3",
}


def firmware():
    out = []
    for set_id, s in SETS.items():
        cond = {"setting": "model", "in": s["models"]} if len(s["models"]) > 1 else \
            {"setting": "model", "is": s["models"][0]}
        if "free" in s:
            cond = {"all": [cond, {"setting": "freeTownsRoms", "is": s["free"]}]}
        for name, (size, sha1) in s["files"].items():
            f = FILE_KEYS[name]
            out.append({
                "id": name,
                "display": f"firmware.{f}",
                "description": f"firmware.{set_id}.about",
                "label": f"firmware.{set_id}.{f}",
                "name": name,
                "size": size,
                "sha1": sha1,
                "requiredWhen": cond,
            })
    return out


def setting(name, options, default, labelled=None, **extra):
    """labelled: the options that have words of their own (all by default);
    a number shows as itself."""
    s = {"name": name, "display": f"setting.{name.lower()}", "description": f"setting.{name.lower()}.about"}
    if options is None:
        s["type"] = "bool"
    else:
        s["type"] = "enum"
        s["options"] = options
        s["optionLabels"] = {o: f"setting.{name.lower()}.{o.lower()}" for o in options
                             if labelled is None or o in labelled}
    s["default"] = default
    s["sync"] = True
    s.update(extra)
    return s


def settings():
    ports = ["auto", "pad", "pad6", "martyPad", "mouse", "none"]
    return [
        setting("model", MODELS, "model1_2"),
        setting("freeTownsRoms", None, False,
                exposedWhen={"setting": "model", "is": "model1_2"}),
        setting("cpuMhz", ["auto", "16", "20", "25", "33", "40", "50", "66", "100"], "auto", ["auto"]),
        setting("ramMb", ["auto", "1", "2", "4", "6", "8", "10", "12", "16", "20", "24", "32", "48", "64", "96"], "auto", ["auto"]),
        setting("fpu", ["auto", "off", "on"], "auto"),
        setting("speedMode", ["auto", "off", "on"], "auto"),
        setting("bootDevice", ["auto", "cdrom", "floppy1", "floppy2"], "auto"),
        setting("portA", ports, "auto"),
        setting("portB", ports, "auto"),
    ]


def config(ks):
    buttons = CONSOLE + [f"P{p} {b}" for p in (1, 2) for b in PAD] + MOUSE + [f"Key {k[0]}" for k in ks]
    mnemonics = {"Power": "P", "Reset": "r", "Next Floppy Disk": "f", "Next CD": "c",
                 "Up": "U", "Down": "D", "Left": "L", "Right": "R", "Select": "s", "Run": "S",
                 "A": "A", "B": "B", "C": "C", "X": "X", "Y": "Y", "Z": "Z", "Zoom": "z",
                 "Mouse Left": "l", "Mouse Right": "q"}
    # the console's and the mouse's controls sit in one group with the
    # keyboard, so each gets a header no key has
    headers = {"Power": "PWR", "Reset": "RST", "Next Floppy Disk": "FDD", "Next CD": "CD",
               "Mouse Left": "ML", "Mouse Right": "MR"}
    for label, _code, mnem, header, _bind in ks:
        mnemonics[f"Key {label}"] = mnem
        headers[f"Key {label}"] = header
    return {
        "coreName": "Geartowns",
        "systemId": "FMTowns",
        "systemNames": {"FMTowns": "FM Towns"},
        "author": "Ignacio Sanchez (drhelius); chimera port by Sergio Martin",
        "url": "https://github.com/ToolAssisted-run/chimera-core-geartowns",
        "runsOn": ["windows-x86_64", "linux-x86_64", "macos-x86_64",
                   "windows-aarch64", "linux-aarch64", "macos-aarch64"],
        "romFile": "rom",
        "deterministic": True,
        "memoryLayoutMiB": [64, 4, 16, 16, 768],
        "_memoryLayoutMiB_note": "sbrk, sealed, invisible, plain, mmap. Main RAM (up to about 100 MB on the last models), the floppy images and the CD's cache are allocated on the mmap heap.",
        "video": {
            "_comment": "the buffer's capacity; the live size comes from GetVideoWidth/Height every frame (640x480 and 640x400 are the usual modes, 1024x768 the high-resolution one)",
            "width": 1024,
            "height": 768,
            "virtualWidth": 640,
            "virtualHeight": 480,
            "vsyncNumerator": 60,
            "vsyncDenominator": 1,
            "getBgra": "GetVideoBgra",
        },
        "audio": {"samplesPerFrame": 4096, "channels": 2, "rate": 44100, "get": "GetAudio"},
        "lag": {"inputWasRead": "InputWasRead"},
        "input": {
            "name": "FM Towns",
            "_comment": "the wire's order: the console's buttons, the pads on game ports A and B, the mouse's two buttons, then the keyboard (waterbox/keys.h). Wider than 64, so everything rides SetButton; the mouse's movement rides SetAxis. Which pad or mouse a game sees follows the portA and portB settings.",
            "buttons": buttons,
            "mnemonics": mnemonics,
            "headers": headers,
            "axes": [
                {"name": "Mouse X", "min": -127, "max": 127, "neutral": 0, "header": "mX"},
                {"name": "Mouse Y", "min": -127, "max": 127, "neutral": 0, "header": "mY"},
            ],
            "players": [[f"P1 {b}" for b in PAD], [f"P2 {b}" for b in PAD]],
            "tastudioColumns": ["P1 Up", "P1 Down", "P1 Left", "P1 Right", "P1 Select", "P1 Run",
                                "P1 A", "P1 B", "Mouse Left", "Mouse Right", "Mouse X", "Mouse Y",
                                "Key Return", "Key Space", "Key Escape"],
        },
        "extensions": {e: "FMTowns" for e in [".cue", ".iso", ".chd", ".d77", ".d88", ".hdm", ".xdf", ".mfm"]},
        "settings": settings(),
        "firmware": firmware(),
    }


def keybinds(ks):
    pad = {
        "P1 Up": "Up, J1 POV0U, X1 DpadUp, X1 LStickUp",
        "P1 Down": "Down, J1 POV0D, X1 DpadDown, X1 LStickDown",
        "P1 Left": "Left, J1 POV0L, X1 DpadLeft, X1 LStickLeft",
        "P1 Right": "Right, J1 POV0R, X1 DpadRight, X1 LStickRight",
        "P1 Select": "J1 B9, X1 Back",
        "P1 Run": "J1 B10, X1 Start",
        "P1 A": "J1 B1, X1 A",
        "P1 B": "J1 B2, X1 B",
        "P1 C": "J1 B3, X1 RightShoulder",
        "P1 X": "J1 B4, X1 X",
        "P1 Y": "J1 B5, X1 Y",
        "P1 Z": "J1 B6, X1 LeftShoulder",
        "P1 Zoom": "J1 B7, X1 LeftTrigger",
    }
    binds = {b: "" for b in CONSOLE}
    for p in (1, 2):
        for b in PAD:
            binds[f"P{p} {b}"] = pad.get(f"P{p} {b}", "")
    binds["Mouse Left"] = "WMouse L"
    binds["Mouse Right"] = "WMouse R"
    for label, _code, _m, _h, bind in ks:
        binds[f"Key {label}"] = bind
    return {
        "_comment": [
            "Default bindings: player 1's pad on a game controller and on the arrow keys,",
            "the mouse on the host's mouse, and the FM Towns keyboard on the host keyboard,",
            "key for key where the two have one (waterbox/keys.h). Player 2's pad, Power,",
            "Reset and the disk controls ship unbound. A person's own bindings always win.",
        ],
        "AllTrollers": {"FM Towns": binds},
        "AllTrollersAnalog": {"FM Towns": {
            "Mouse X": {"Value": "RMouse X", "Mult": 1.0, "Deadzone": 0.0},
            "Mouse Y": {"Value": "RMouse Y", "Mult": 1.0, "Deadzone": 0.0},
        }},
    }


def main():
    ks = keys()
    outputs = {
        os.path.join(here, "waterbox.config"): json.dumps(config(ks), indent=1, ensure_ascii=True) + "\n",
        os.path.join(here, "default_keybinds.json"): json.dumps(keybinds(ks), indent=1, ensure_ascii=True) + "\n",
    }
    if "--check" in sys.argv[1:]:
        bad = [p for p, t in outputs.items() if not os.path.exists(p) or open(p).read() != t]
        if bad:
            sys.exit("not what gen-config.py writes: " + ", ".join(os.path.basename(p) for p in bad))
        print("waterbox.config and default_keybinds.json are what gen-config.py writes")
        return
    for p, t in outputs.items():
        open(p, "w").write(t)
    print(f"wrote waterbox.config ({len(config(ks)['input']['buttons'])} buttons) and default_keybinds.json")


main()
