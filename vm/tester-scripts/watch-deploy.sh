#!/bin/bash
# Deploy Kernel Watcher for Project225
# By José Puga. 2026

# THIS SCRIPT MUST BE IN THE Tester VM!!!!

set -e
delay=3 # In seconds

cd /mnt/deploy
rm -f DEPLOY.done.*

# Movemos el DEPLOY actual en lugar de borrarlo, esto es porque
# no podemos fiarnos de la caché de NFS v2, moverlo a un nombre
# único nos asegura un comporatamiento sin caché
old_done_file=""

# In kernel 2.2 there is not inotify, fswatch, systemd.path, ...
# We use a loop
while true; do
    if [ -f DEPLOY ]; then
        echo "DEPLOY trigger detected!"
        done_file=DEPLOY.done.$(date +%Y%m%d%H%M%S)
        if mv DEPLOY "$done_file"; then
            if [ -f "$old_done_file" ]; then
                rm -f "$old_done_file"
            fi
            old_done_file="$done_file"
            echo "Calling install-kernel.sh"
            install-kernel.sh
            exit 0
        fi
    fi
    sleep $delay
done