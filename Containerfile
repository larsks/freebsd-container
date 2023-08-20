##
## FETCH INSTALLER
##
## Grab the remote installer image and save it to disk.
FROM docker.io/alpine:3 AS fetch_installer

WORKDIR /freebsd

RUN apk add \
	curl \
	bash
COPY fetch-installer-image.sh ./
RUN bash -x fetch-installer-image.sh

##
## BUILD INSTALLER
##
## Unpack the installer image, apply patches, and re-generate
## an ISO image.
FROM docker.io/alpine:3 AS build_installer

WORKDIR /freebsd

RUN apk add \
	qemu-img \
	qemu-system-x86_64 \
	bash \
	xorriso \
	tar \
	xz

COPY --from=fetch_installer /freebsd/bootonly.iso ./

COPY installer_patches installer_patches/
COPY dists dists/
COPY build-installer-image.sh ./
RUN bash -x build-installer-image.sh

##
## BUILD IMAGE
##
## Boot the installer with QEMU to provision FreeBSD
## onto a disk image.
FROM docker.io/alpine:3 AS build_image

ARG FREEBSD_INSTALL_QUIET=
ARG FREEBSD_BUILD_TIMEOUT=600
ARG FREEBSD_USER_NET=100.64.0.0/24
ARG FREEBSD_IMAGE_SIZE=2G

RUN apk add \
	qemu-img \
	qemu-system-x86_64 \
	bash

WORKDIR /freebsd
COPY --from=build_installer /freebsd/installer.iso ./
COPY build-freebsd-image.sh ./
RUN bash build-freebsd-image.sh

##
## FINAL IMAGE
##
## Prepare the final container image.
FROM docker.io/alpine:3

ARG FREEBSD_USER_NET=100.64.0.0/24
ENV FREEBSD_USER_NET=${FREEBSD_USER_NET}

RUN apk add \
	bash \
	qemu-img \
	qemu-system-x86_64 \
	openssh \
	darkhttpd \
	curl

WORKDIR /freebsd
COPY --from=build_image /freebsd/freebsd-*.img ./
COPY --from=build_image /freebsd/freebsd.img.sha256 ./
COPY start-freebsd.sh ./
COPY container-entrypoint.sh ./

ENTRYPOINT ["bash", "container-entrypoint.sh"]
CMD ["bash", "start-freebsd.sh"]
