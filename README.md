# FreeBSD in a Container

This project builds a container image that boots FreeBSD.

## Logging in

You can log in as `root` with no password on the console.

If you mount a volume on `/shared` with an `authorized_keys` file, you will be able to ssh into the image as the `freebsd` user using the corresponding private key. E.g:

```
$ ls shared
authorized_keys
$ podman run --rm -d --name freebsd -p 2200:22 -v $PWD/shared:/shared freebsd
...
$ ssh -p 2200 freebsd@localhost
...
freebsd@:~ $
```

The `freebsd` user has passwordless `sudo` privileges.

## Persistence

If you mount a volume on `/disk`, the container will create a copy-on-write disk image in that directory that contains any changes made to the disk image. Additionally, the filesystem will automatically grow to the size of your image, which you can specify by setting the `FREEBSD_COW_SIZE` environment variable (default is 10G). E.g:

```
$ podman run --rm -it --name freebsd -v freebsd_disk:/disk -e FREEBSD_COW_SIZE=20G freebsd
...
root@:~ # df -h /
Filesystem      Size    Used   Avail Capacity  Mounted on
/dev/vtbd0p2     19G    1.4G     16G     8%    /
```

## Technical notes

### Forwarding ports

By default, container port 22 forwards to port 22 in the FreeBSD virtual machine.  You can set up additional port forward using the `FREEBSD_PORTS` environment variable.  For example, if you want to run a web server under FreeBSD and access it from the container host, you might run:

```
podman run --rm \
  -e FREEBSD_PORTS='80:80' -p 8080:80 \
  -v $PWD/shared:/shared  -p 2200:22 \
  freebsd
```

Where `-v $PWD/shared:/shared -p 2200:22` sets up our ssh access, and `-e FREEBSD_PORTS='80:80' -p 8080:80` sets up the QEMU port forward to connect container port 80 to vm port 80, and then exposes container port 80 on host port 8080, allowing us to access the FreeBSD web server from our container host at `http://localhost:8080`.

### QEMU user networking

QEMU user networking defaults to using the 10.0.2.0/24 network. This is unfortunate because this address range may also be used by your container runtime, which will break networking. There is an obvious solution used by most container runtimes (don't use an address range for which the host has an existing non-default route), but that hasn't been implemented in QEMU. To attempt to prevent this sort of conflict, QEMU in this image is configured to use a portion of the [carrier-grade NAT network range][cgnat]. The carriet grade NAT range is 100.64.0.0/10, but this image uses only 100.64.0.0/24.

[cgnat]: https://en.wikipedia.org/wiki/Carrier-grade_NAT

You can select a different range by setting the `FREEBSD_USER_NET` environment variable:

```
$ podman run --rm -e FREEBSD_USER_NET=192.168.31.0/24 freebsd
...
root@~ # ifconfig
vtnet0: flags=8863<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
        options=80028<VLAN_MTU,JUMBO_MTU,LINKSTATE>
        ether 52:54:00:12:34:56
        inet 192.168.31.15 netmask 0xffffff00 broadcast 192.168.31.255
        media: Ethernet autoselect (10Gbase-T <full-duplex>)
        status: active
        nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>
```

### FreeBSD installer patches

This repository patches some components of the FreeBSD installer to work around the following bugs:

- [#273148]
- [#273192]

[#273148]: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=273148
[#273192]: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=273192

These patches may need updating if you want to install anything other than FreeBSD 13.2-RELEASE.
