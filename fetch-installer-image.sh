#!/bin/bash

: "${FREEBSD_BOOTONLY_URL:="https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/13.2/FreeBSD-13.2-RELEASE-amd64-bootonly.iso"}"

set -e

curl -sSf -o bootonly.iso "${FREEBSD_BOOTONLY_URL}"
