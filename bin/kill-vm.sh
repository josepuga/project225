#!/usr/bin/env bash
# Stop and Close the VM
# Project225. By José Puga 2026

set -uo pipefail

role="${1:-}"

[ -z "$role" ] && {
    echo "This script forces the VM quit."
    echo "Try first to shut it down and quit manually."
    echo "Usage: $0 {builder|tester}"
    exit 1
}

case "$role" in
    builder|tester)  ;;
    *) 
        echo "unknown VM role: $role"
        exit 1
        ;;
esac

d="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$d/vm-$role.pid"
qmp_file="$d/vm-$role.qmp"   #Unix Socket!

# First check if the vm is already running.
if [[ ! -f "$pid_file" ]] || ! kill -0 "$(<"$pid_file")" 2>/dev/null; then
    echo "The VM $role is already stopped."
    exit 0
fi
socket="UNIX-CONNECT:$qmp_file"

# Slackware 7/8 dont have ACPI function. Sending shutdown/powerdown doest work
# Sending quit instead
#set +e
printf '{"execute": "qmp_capabilities" }\n{"execute": "quit"}\n' \
    | socat - "$socket" &> /dev/null || true
#set -e
