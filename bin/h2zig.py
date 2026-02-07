#!/usr/bin/env python3
#
# h2zig.py — C header → Zig defines generator
# Project225
#

import sys
import os
import re


# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

# Where generated Zig files are written
OUTPUT_PATH = "."


# ------------------------------------------------------------
# Regex patterns
# ------------------------------------------------------------

# #define NAME    (no value)
RE_FLAG = re.compile(r"^#define\s+(\w+)\s*$")

# #define NAME 123
RE_NUMBER = re.compile(r"^#define\s+(\w+)\s+([0-9]+)$")

# #define NAME "text"
RE_STRING = re.compile(r'^#define\s+(\w+)\s+"([^"]*)"')

# #define NAME expr
RE_EXPR = re.compile(r"^#define\s+(\w+)\s+(.+)$")

# #define MACRO(x,y)
RE_MACRO = re.compile(r"^#define\s+(\w+)\s*\(")

# #if / #ifdef / #endif / ...
RE_IF = re.compile(r"^#\s*(if|ifdef|ifndef|elif|else|endif)\b(.*)")

# #include <...> / "..."
RE_INCLUDE = re.compile(r"^#\s*include\s+(.+)")

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------


def zig_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def ensure_output_dir():
    if not os.path.isdir(OUTPUT_PATH):
        os.makedirs(OUTPUT_PATH, exist_ok=True)


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------


def main():

    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} file.h")
        sys.exit(1)

    header = sys.argv[1]

    if not os.path.isfile(header):
        print(f"Error: {header} not found")
        sys.exit(1)

    ensure_output_dir()

    base = os.path.splitext(os.path.basename(header))[0]

    out_defs = os.path.join(OUTPUT_PATH, base + "_h.zig")
    out_macros = os.path.join(OUTPUT_PATH, base + "_macros_h.zig")

    defines = []
    macros = []

    # --------------------------------------------------------
    # Parse header
    # --------------------------------------------------------

    with open(header, "r", encoding="utf-8", errors="ignore") as f:

        for lineno, line in enumerate(f, 1):

            raw = line.rstrip("\n")
            line = raw.strip()

            # --------------------------------------------
            # Preprocessor conditionals → comments
            # --------------------------------------------

            m = RE_IF.match(line)
            if m:
                kind, rest = m.groups()
                defines.append(("__COMMENT__", f"// #{kind}{rest}"))
                continue

            # --------------------------------------------
            # Includes → comments
            # --------------------------------------------

            m = RE_INCLUDE.match(line)
            if m:
                inc = m.group(1)
                defines.append(("__COMMENT__", f"// #include {inc}"))
                continue

            # --------------------------------------------
            # Only care about #define from here
            # --------------------------------------------

            if not line.startswith("#define"):
                continue

            # --------------------------------------------
            # Macro with arguments
            # --------------------------------------------

            if RE_MACRO.match(line):
                macros.append((lineno, raw))
                continue

            # --------------------------------------------
            # Flag define (no value)
            # --------------------------------------------

            m = RE_FLAG.match(line)
            if m:
                name = m.group(1)
                defines.append(("__COMMENT__", f"// #define {name}"))
                continue
            
            # --------------------------------------------
            # Number
            # --------------------------------------------

            m = RE_NUMBER.match(line)
            if m:
                name, val = m.groups()
                defines.append((name, val))
                continue

            # --------------------------------------------
            # String
            # --------------------------------------------

            m = RE_STRING.match(line)
            if m:
                name, val = m.groups()
                val = zig_escape(val)
                defines.append((name, f'"{val}"'))
                continue

            # --------------------------------------------
            # Expression / fallback
            # --------------------------------------------

            m = RE_EXPR.match(line)
            if m:
                name, val = m.groups()

                if val.strip():
                    defines.append((name, val.strip()))

                continue

    # --------------------------------------------------------
    # Write _h.zig
    # --------------------------------------------------------

    with open(out_defs, "w") as f:

        f.write(f"// AUTO-GENERATED from {header}\n")
        f.write("// DO NOT EDIT MANUALLY\n\n")

        for name, val in defines:

            if name == "__COMMENT__":
                f.write(val + "\n")
            else:
                f.write(f"pub const {name} = {val};\n")

    # --------------------------------------------------------
    # Write _macros.zig (if needed)
    # --------------------------------------------------------

    if macros:

        with open(out_macros, "w") as f:

            f.write(f"// AUTO-GENERATED MACROS FROM {header}\n")
            f.write("// REVIEW AND PORT MANUALLY\n\n")

            for lineno, line in macros:
                f.write(f"// line {lineno}: {line}\n")

    else:

        if os.path.exists(out_macros):
            os.unlink(out_macros)

    # --------------------------------------------------------
    # Summary
    # --------------------------------------------------------

    print(f"Generated: {out_defs}")

    if macros:
        print(f"Generated: {out_macros} ({len(macros)} macros)")
    else:
        print("No macros found")


# ------------------------------------------------------------

if __name__ == "__main__":
    main()
