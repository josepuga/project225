#!/bin/bash
# Sets the kernel source, Makefile and .config by default 
# For Project225
# By José Puga. 2026

# THIS SCRIPT MUST BE IN THE Builder VM!!!!

set -e
version="2.2.5"

base_path="/usr/src"
src_path="$base_path/linux-$version"
backup_path=~/backup
kernel_file="$backup_path/kernel-2.2.5.tar.gz"
config_file="$backup_path/config-2.2.5"


# Check .config backup and print warning if not
[ ! -f "$config_file" ] && {
    echo "Backup .config $config_file not found."
    echo "Make sure you have a copy of $src_path/.config"
    echo   
}

echo "WARNING: All content of $src_path will be deleted!!!"
echo "         Be sure the builder has UNMOUNTED kernel-shared"
echo
echo "Press Y to continue, any other key to cancel"

read -s -n 1 -p "" response &> /dev/null

[[ "$response" != "y" && "$response" != "Y" ]] && {
    exit 1
}

# Check if kernel backup exists
[ ! -f "$kernel_file" ] && {
    echo "Backup kernel $kernel_file does not exists!"
    exit 1
}

if [ ! -d "$src_path" ]; then
    echo "$src_path: Directory does not exist. Creating..."
    mkdir -p "$src_path"
else  
    echo "$src_path: Directory exist. Deleting content..."
    rm -fr "$src_path" # o_O
fi

cd "$base_path"
echo "Uncompressing 2.2.5 kernel in $src_path..."
tar zxf "$kernel_file" --no-same-owner

echo "Creating some directories and files..."
mkdir -p "$src_path/log" "$src_path/zig"

# Config file if exists
[ -f "$config_file" ] && {
    cp "$config_file" "$src_path/.config"
}

echo "Patching Makefile..."
echo '-include $(TOPDIR)/zig/override.mk' >> "$src_path/Makefile"

echo "Generating linux softlink..."
rm -f linux
ln -s "linux-$version" linux

echo "Done!"



