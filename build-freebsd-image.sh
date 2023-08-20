#!/bin/bash

: "${FREEBSD_USER_NET:=100.64.0.0/24}"
: "${FREEBSD_BUILD_TIMEOUT:=400}"
: "${FREEBSD_IMAGE_SIZE:=2G}"

set -e

: "${installer_iso:=installer.iso}"
: "${freebsd_image:="$(mktemp -u freebsdXXXXXX)"}"

qemu-img create -f qcow2 "${freebsd_image}" "${FREEBSD_IMAGE_SIZE}"

qemu_args=()

# Set the FREEBSD_INSTALL_QUIET build argument to a non-empty value to
# hide the console when running the installer. Special values
# `graphic` and `serial` are for use when testing.
if [[ $FREEBSD_INSTALL_QUIET == graphic ]]; then
	qemu_args+=( -serial mon:stdio )
elif [[ $FREEBSD_INSTALL_QUIET == serial ]]; then
	qemu_args+=( -nographic -serial mon:stdio )
elif [[ -n $FREEBSD_INSTALL_QUIET ]]; then
	qemu_args+=( -nographic -monitor none -serial none )
else
	qemu_args+=( -nographic -monitor none -serial stdio )
fi

timeout "${FREEBSD_BUILD_TIMEOUT}" \
qemu-system-x86_64 -smp 1 -m 256 \
	-cdrom "${installer_iso}" \
	-drive if=virtio,format=qcow2,cache=unsafe,file="${freebsd_image}" \
	-netdev user,id=net0,net="${FREEBSD_USER_NET}" \
	-device virtio-net-pci,netdev=net0 \
	"${qemu_args[@]}"

read -r -a checksum < <(sha256sum "${freebsd_image}")
echo "${checksum}" > "freebsd.img.sha256"
mv "${freebsd_image}" "freebsd-${checksum}.img"
