#!/bin/bash

set -e

: "${source_iso:=bootonly.iso}"
: "${installer_iso:=installer.iso}"
if [[ -z $workspace ]]; then
	workspace=$(mktemp -d /tmp/buildXXXXXX)
	trap 'rm -rf $workspace' EXIT
fi

echo "copying installer files"
xorriso -osirrox on -indev "${source_iso}" -extract / "${workspace}"

echo "applying patches"
tar -C installer_patches -cf- . | tar -C "${workspace}" --no-same-owner -xf-

echo "building dists"
for dist in dists/*; do
	distname=${dist##*/}
	tar --xz -C "${dist}" \
		--owner 0 \
		--group 0 \
		-cf "${workspace}/usr/freebsd-dist/${distname}.txz" .
	read -r -a checksum < <(sha256sum "${workspace}/usr/freebsd-dist/${distname}.txz")
	printf "%s.txz\t%s\t%s\t%s\t\"%s\"\n" \
		"${distname}" \
		"${checksum}" \
		"000" \
		"containerservices" \
		"Container services" \
		>> "${workspace}/usr/freebsd-dist/MANIFEST"
done

echo "configuring bootloader"
cat >> "$workspace"/boot/loader.conf <<EOF
autoboot_delay="0"
console="comconsole"
comconsole_speed="115200"
EOF

echo "building image"
mkisofs -D -R -b boot/cdboot -allow-leading-dots -no-emul-boot \
	-input-charset utf-8 \
	-o installer.iso -V FREEBSD_INSTALL "${workspace}"
