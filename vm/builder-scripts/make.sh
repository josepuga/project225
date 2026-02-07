#!/bin/bash
# Auto kernel compiler for Project225
# By José Puga. 2026

# THIS SCRIPT MUST BE IN THE Builder VM!!!!

set -e

cd /usr/src/linux
mkdir -p log

# If not .config use the backup
backup_config=~/backup/config-2.2.5
[ -f "$backup_config" ] && [ ! -f ".config" ] && {
    echo "Restoring .config backup..."
    cp "$backup_config" ".config"
}

# Ensure kernel is configured
if [ ! -f include/linux/autoconf.h ]; then
    echo "include/linux/autoconf.h not found:"
    for step in oldconfig dep; do
        echo "   Running: make $step to log/make-$step.log"   
        make $step > log/make-$step.log 2>&1
    done
    echo 
fi

for step in bzImage modules modules_install; do
    echo "Running: make $step to log/make-$step.log"
    make $step > log/make-$step.log 2>&1
    echo "Done: make $step"
    echo
done

# Show Zig modules info
grep "ZIG:" log/make-bzImage.log || true
echo 
echo "OK"
echo
