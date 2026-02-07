#!/bin/bash
# Deploys kernel for Project225
# By José Puga. 2026

# THIS SCRIPT MUST BE IN THE Builder VM!!!!

set -e

cd /usr/src/
mkdir -p deploy
linux_version=$(grep UTS_RELEASE linux/include/linux/version.h | cut -d'"' -f2)
tar zcf deploy/modules-test.tar.gz -C /lib "modules/$linux_version"
cp linux/arch/i386/boot/bzImage deploy/vmlinuz-test

# Metadata: KernelVersion-YYMMDDHHMMSS
metadata="$linux_version-$(date +%Y%m%d%H%M%S)"
# Create the "flag file". This triggers the LILO installation of the
# new kernel if the Tester VM is running the watcher.
echo "$metadata" > deploy/DEPLOY
