#!/bin/sh

: "${SHARED_DIR:=/shared}"

set -e

## If the user doesn't provide an authorized_keys file, create an ssh
## keypair in /shared. Either the user can retrieve the private key from
## a bind mount, or use `podman cp` (or just `podman exec` into the image
## and run ssh there).
mkdir -p "${SHARED_DIR}"
if [ ! -f "${SHARED_DIR}"/authorized_keys ]; then
	private_key=$(mktemp -u "${SHARED_DIR}/freebsd_rsa_XXXXXX")
	ssh-keygen -f "${private_key}" -N '' -C 'FreeBSD Container' -t rsa -b 4096
	mv "${private_key}.pub" "${SHARED_DIR}/authorized_keys"
fi

## Start a simple webserver so that the FreeBSD can access files from
## the shared directory.
darkhttpd "${SHARED_DIR}" --addr 127.0.0.1 --port 8080 &

exec "$@"
