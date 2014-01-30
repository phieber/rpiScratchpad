#!/bin/bash
#
# Author: Patrick Hieber - github.com/phieber
#
# This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.

rm -rf /tmp/rpi*
mkdir /tmp/rpi

wget -c -O - http://gentoo.osuosl.org/releases/arm/autobuilds/current-stage3-armv6j_hardfp/$(wget -O - http://gentoo.osuosl.org/releases/arm/autobuilds/current-stage3-armv6j_hardfp/ 2>&1 | grep armv6j | grep ".tar.bz2\"" | cut -d'"' -f6) | tar xfpj - -C /tmp/rpi

wget -c -O - http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2 | tar xjf - -C /tmp/rpi/usr

git clone --depth 1 git://github.com/raspberrypi/firmware/ /tmp/rpiFirmware
cp /tmp/rpiFirmware/boot/* /tmp/rpi/boot/
cp -r /tmp/rpiFirmware/modules /tmp/rpi/lib/

sed -ie 's@^/@#/@g;' /tmp/rpi/etc/fstab
echo -e '@BOOT@\t/boot\tvfat\tdefaults\t0\t0' >> /tmp/rpi/etc/fstab

echo 'ipv6.disable=1 avoid_safe_mode=1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=@ROOT@ rootfstype=ext4 elevator=noop rootwait' > /tmp/rpi/boot/cmdline.txt

sed -ie 's@^\(root:\)\*\(.*\)@\1$6$sWmzkD4k$c0mMp/uShHALAPSnYyECig8FxOMUQZ7nf2uUPF/xj2iCD13qDpEE69V.8MuqkGW27i7gQNQ8neDhUDizTfcCb0\2@g;' /tmp/rpi/etc/shadow

cp /tmp/rpi/usr/share/zoneinfo/Europe/Berlin /tmp/rpi/etc/localtime
echo 'Europe/Berlin' > /tmp/rpi/etc/timezone
