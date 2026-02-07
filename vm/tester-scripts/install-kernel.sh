#!/bin/bash
# Install Kernel for Project225
# By José Puga. 2026

# THIS SCRIPT MUST BE IN THE Tester VM!!!!

set -e
kernel_file=vmlinuz-test
modules_file=modules-test.tar.gz

cd /mnt/deploy
echo "Copying $kernel_file to /boot..."
cp "$kernel_file" /boot
echo "Installing kernel modules..."
tar xzf "$modules_file" -C /lib
echo "Configuring LILO and Rebooting..."
lilo -v && reboot
