#!/usr/bin/env bash
# Creates and/or runs the VMs
# Project225. By José Puga 2026

# Set to 1 to use the host shell as session
host_shell=1
# Set to 0 to hidde the VM. QEMU does not show up the window.
show_vm=1 

set -euo pipefail
cd "$(dirname "$0")"/..

role="${1:-}"

[ -z "$role" ] && {
    echo "This script launches and/or creates the VM"
    echo "Usage: $0 {builder|tester}"
    exit 1
}

declare -A vm_builder
declare -A vm_tester

# Si C no es arrancable (antes de la instalación), autom. se arranca del cdrom
# boot_drive=c

vm_builder=(
    ["name"]="builder"
    ["host_shell"]=$host_shell
    ["show_vm"]=$show_vm
    ["ram"]=512M
    ["hda_file"]=vm/slackware81.qcow2
    ["hda_size"]=2G
    #["iso_file"]=iso/slackware81.iso
    ["boot_drive"]=c
    ["rtc"]="base=localtime"
    ["netdev"]="bridge,id=net0,br=virbr0" 
    ["device"]="ne2k_pci,netdev=net0,mac=00:00:02:02:05:81"
    ["vga"]=cirrus
)

vm_tester=(
    ["name"]="tester"
    ["host_shell"]=$host_shell
    ["show_vm"]=$show_vm
    ["ram"]=128M
    ["hda_file"]=vm/slackware71.qcow2
    ["hda_size"]=1G
    #["iso_file"]=iso/slackware71.iso
    ["boot_drive"]=c
    ["rtc"]="base=localtime"
    ["netdev"]="bridge,id=net0,br=virbr0"
    ["device"]="ne2k_pci,netdev=net0,mac=00:00:02:02:05:71"
    ["vga"]=cirrus
)

case "$role" in
    builder) declare -n vm=vm_builder ;;
    tester) declare -n vm=vm_tester ;;
    *) 
        echo "unknown VM role: $role"
        exit 1
        ;;
esac

backup_file="backup/$role-qemu-disk.tar.gz"

### COMPROBAR RED PARA USAR NFS

bridge_conf=/etc/qemu/bridge.conf
# Hace falta que la VM esté conectada en la LAN local ya que hará de servidor NFS
[ ! -f "$bridge_conf" ] && {
    echo "Error: $bridge_conf not found"
    echo 
    echo "This file is necessary to grant QEMU net bridger permissions without run as root"
    echo "Usually is created by libvirt. After install it, must be exists."
    exit 1
}

bridge=$(grep ^allow "$bridge_conf" 2>/dev/null | head -1 | cut -f 2 -d " " ) || true

[ "$bridge" = "" ] && {
    echo "Error: not allowed bridget in $bridge_conf"
    echo
    echo "QEMU can only run explicit authorized bridgets."
    echo "Try to add in $bridge_conf this line:"
    echo "allow virbr0"
    exit 1
}

echo "Net bridge $bridge detected"
echo "Be sure libvirtd is active: systemctl status libvirtd"

qemu_args=(
    qemu-system-i386
    -name "${vm[name]}"
    -m "${vm[ram]}"
    -hda "${vm[hda_file]}"
    #-cdrom "${vm[iso_file]}"
    -boot "${vm[boot_drive]}"
    -rtc "${vm[rtc]}"
    -netdev "${vm[netdev]}"
    -device "${vm[device]}"
    -vga "${vm[vga]}"
)

# Create disk C if not exists
[ ! -f "${vm[hda_file]}" ] && {
    echo "C disk not detected, creating from backup..."

    [ ! -f "$backup_file" ] && {
        echo "Backup file $backup_file not found. Aborting."
        exit 1
    }

    tar zxf "$backup_file" -C vm/
}

[ "${vm[host_shell]}" -eq 1 ] && {
    qemu_args+=(
    # Permite usar la consola del host com si fuera la de la VM
    -nographic -serial mon:stdio
    )
}

[ "${vm[show_vm]}" -eq 1 ] && { #IMPORTANT: Must be AFTER $host_shell!!!!!!
    # Evita miniimagen, la VM se adapta a la ventana
    qemu_args+=(
    -display "gtk,zoom-to-fit=on"
    )
}

qemu_args+=(
    # Mejorar la velocidad de la CPU. ideal para compilar
    -enable-kvm -cpu host
)

printf '%q ' "${qemu_args[@]}"
echo
"${qemu_args[@]}"
