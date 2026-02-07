#!/usr/bin/env bash
# 
# Project225. By José Puga 2026

set -euo pipefail
cd "$(dirname "$0")"/..

server_ip=192.168.122.81
server_mount_point=/usr/src/linux
client_mount_point=kernel-shared

mount_options="vers=3,tcp,nolock"
mount_options+=",noac,soft,intr,timeo=80,retrans=2,lookupcache=none"

if ! ping -c 1 "$server_ip" &> /dev/null; then
    echo "Error: Looks like VM builder is down."
    echo
    echo "builder IP is $server_ip."
    echo "To confirm this IP from builder VM type: ifconfig" 
    exit 1

fi

if mountpoint -q "$client_mount_point"; then
    echo "Filesystem $client_mount_point already mounted."
    echo 
    echo "Umount manually with:"
    echo "    sudo umount $client_mount_point"
    echo 
    echo "Be sure there is not processes using it:"
    echo "    lsof +d $client_mount_point"
    exit 0
fi

mount_args=(
    sudo mount -v -t nfs 
    -o "$mount_options"
    "$server_ip":"$server_mount_point"
    "$client_mount_point"
)

showmount -e "$server_ip"
echo
echo "Running:" 
printf '%q ' "${mount_args[@]}"
echo
echo "¡root permissions are needed!"
echo
"${mount_args[@]}"