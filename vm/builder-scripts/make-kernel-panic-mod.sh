#!/bin/bash
# Project225. José Puga 2026
# This script must be compatible with Bash 2.04
#
# Compiles the kernel panic module for tester

set -e

mod_file=/usr/src/deploy/panic.o
kernel_src_patch=/usr/src/linux-2.2.5

[ ! -f "$kernel_src_patch/include/linux/version.h" ] && {
    echo "$kernel_src_patch/include/linux/version.h" not found!
    echo "This file is necessary to compile the module."
    echo "Run script make.sh to compile the kernel before continue"
    exit 1
}


[ -f "$mod_file" ] && {
    echo "$mod_file already exists. Creating again..."
}

src_file=/tmp/panic.c
obj_file=/tmp/panic.o

# Create Source Code
cat > "$src_file" <<EOL
#include <linux/module.h>
#include <linux/kernel.h>

// By default the kernel version is bind to the "real" booted kernel o_O

int init_module(void) {
    panic("panic from module: Zig panic test OK");
    return 0;
}

void cleanup_module(void) {}
EOL

# Compile it
gcc -D__KERNEL__ -DMODULE -O2 -fomit-frame-pointer \
    -I"$kernel_src_patch/include" \
    -c "$src_file" -o "$obj_file" && 
ld -r -o "$mod_file" "$obj_file"
rm -f "$obj_file" "$src_file"

echo "Kernel Panic Module created: $mod_file"

