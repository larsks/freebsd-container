#!/bin/bash

: "${FREEBSD_USER_NET:=100.64.0.0/24}"
: "${FREEBSD_MEMORY:=2048}"
: "${FREEBSD_CPUS:=1}"
: "${FREEBSD_COW_SIZE:=10G}"

build_qemu_hostfwd() {
    # convert FREEBSD_PORTS into an array
    read -r -a freebsd_ports <<< "$FREEBSD_PORTS"

    # build hostfwd arguments
    for spec in "${freebsd_ports[@]}"; do
        [[ $spec =~ (([0-9.]+):)?([0-9]+):([0-9]+)(/(tcp|udp))? ]]
        hostfwd="$hostfwd,hostfwd=${BASH_REMATCH[6]:-tcp}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]}-:${BASH_REMATCH[4]}"
    done
}

set -e

## Extract checksum and build filename
checksum=$(cat "freebsd.img.sha256")
freebsd_image="freebsd-${checksum}.img"
freebsd_cow="/disk/${freebsd_image}"

## See if a container volume is available for the COW file, and
## create the COW file if necessary.
if [[ -d ${freebsd_cow%/*} ]]; then
	if ! [[ -f ${freebsd_cow} ]]; then
		qemu-img create -b "$PWD/${freebsd_image}" \
			-f qcow2 -F qcow2 "${freebsd_cow}" "${FREEBSD_COW_SIZE}"
	fi

	freebsd_image=${freebsd_cow}
fi

build_qemu_hostfwd

## Boot the image using QEMU.
exec qemu-system-x86_64 \
        -drive if=virtio,format=qcow2,file="${freebsd_image}" \
        -m "${FREEBSD_MEMORY}" \
        -netdev user,id=net0,net="${FREEBSD_USER_NET}",hostfwd=tcp::22-:22"$hostfwd" \
        -device virtio-net-pci,netdev=net0 \
        -serial mon:stdio \
        -nographic
