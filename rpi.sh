#!/bin/bash


# make a fresh rpi image

# inspired by https://wiki.gentoo.org/wiki/Raspberry_Pi

# ./rpi n # whereas n is the image size in GB
# ./rpi sdx # for exact sd card size termination

# prerequisites: cross compiler,.. installed

# static URL
ARMSTAGE3SUFFIX=$(wget -O - http://distfiles.gentoo.org/releases/arm/autobuilds/latest-stage3-armv6j_hardfp.txt 2>/dev/null | grep -v '^#')
ARMSTAGE3="http://distfiles.gentoo.org/releases/arm/autobuilds/${ARMSTAGE3SUFFIX}"
WD="/tmp"
IMG="rpiGentoo.img"
XCOMPLOC="/tmp/rpiKernel"

# [optional] calculate partition sizes
calc() {
	bc <<-EOI
		$@
		quit
	EOI
}

oneTimeTearDown() {
	umount /dev/loop1
	umount /dev/loop2
	#rm -rf ${WD}/part2
	rm -rf $XCOMPLOC
	losetup -D
}

mkDiskImage() {
	cylinders=
	if echo $1 | grep sd ; then #sd(a,b,c,...)
		dd if=/dev/zero of=${WD}/${IMG} bs=512 count=$(calc $(fdisk -l /dev/sdd | grep Disk | awk '{print $5}')'/512')
		cylinders=$(calc $(fdisk -l /dev/sdd | grep Disk | awk '{print $5}')'/255/63/512')
	else # size in GB
		dd if=/dev/zero of=${WD}/${IMG} bs=512 count=$(calc '('$1'*1024*1024*2*90)/100') # only 90 percent of max size
		cylinders=$(calc '(('$1'*1024*1024*2*90)/100)/255/63/512')
	fi
	fdisk ${WD}/${IMG} <<-EOI
		x
		h
		255
		s
		63
		c
		$cylinders
		r
		n
		p
		1

		+256M
		n
		p
		2


		t
		1
		c
		a
		1
		w
	EOI
	part1Offset=$(fdisk -l ${WD}/${IMG} | grep FAT32 | awk '{print $3}')
	part2Offset=$(fdisk -l ${WD}/${IMG} | grep Linux | awk '{print $2}')
	
	modprobe loop max_part=63

	losetup -o $((512 * $part1Offset)) /dev/loop1 ${WD}/${IMG}
	losetup -o $((512 * $part2Offset)) /dev/loop2 ${WD}/${IMG}

	mkfs.vfat /dev/loop1
	mkfs.ext4 /dev/loop2
}

mountCpEdit() {
	mkdir -p ${WD}/part2
	mount /dev/loop2 ${WD}/part2
	if [ $? -eq 0 ]; then
		wget -O - ${ARMSTAGE3} | tar xfvpj - -C ${WD}/part2/
		# password phieber
		sed -ie 's/^\(root:\)\*\(.*\)/\1$1$F1w24u73$h7vAJbQUb2B8IQr\.3YoRG\.\2/g;' ${WD}/part2/etc/shadow

		mkdir -p ${WD}/part2/boot
		mount /dev/loop1 ${WD}/part2/boot

		# firmware...
		for i in "bootcode.bin" "fixup.dat" "start.elf" "fixup_cd.dat" "start_cd.elf" ; do
			wget -P ${WD}/part2/boot/ https://github.com/raspberrypi/firmware/raw/master/boot/${i}
		done
	fi
}

xCompile() {
	git clone git://github.com/raspberrypi/linux.git ${XCOMPLOC}
	cd ${XCOMPLOC}
	ARCH=arm make bcmrpi_cutdown_defconfig
	ARCH=arm CROSS_COMPILE=/usr/bin/armv6j-hardfloat-linux-gnueabi- make oldconfig
	ARCH=arm CROSS_COMPILE=/usr/bin/armv6j-hardfloat-linux-gnueabi- make -j2
	ARCH=arm CROSS_COMPILE=/usr/bin/armv6j-hardfloat-linux-gnueabi- make modules_install INSTALL_MOD_PATH=${WD}/part2/

	for i in "args-uncompressed.txt" "boot-uncompressed.txt" "first32k.bin" "imagetool-uncompressed.py" ; do
		wget https://github.com/raspberrypi/tools/raw/master/mkimage/${i}
	done

	chmod a+x imagetool-uncompressed.py
	./imagetool-uncompressed.py arch/arm/boot/Image
	cp kernel.img ${WD}/part2/boot/
}

postConfig() {
	chrootDir=${WD}/part2
	#sed -ie 's/BOOT[ \t]+/mmcblk0p1/g;' ${chrootDir}/etc/fstab
	sed -ie 's@^[^#]@##@g;' ${chrootDir}/etc/fstab
	echo '/dev/mmcblk0p1		/boot		auto		noauto,noatime	1 2' >> ${chrootDir}/etc/fstab
	echo '/dev/mmcblk0p2		/		ext2		noatime		0 1' >> ${chrootDir}/etc/fstab
	echo 'root=/dev/mmcblk0p2 rootdelay=2 gpu_mem=8 ' > ${chrootDir}/boot/config.txt

	cp -L /etc/resolv.conf ${chrootDir}/etc/

	chroot ${chrootDir} /bin/bash $(cd /etc/init.d/ && ln -s net.lo net.eth0)
	chroot ${chrootDir} /bin/bash rc-config start net.eth0
	chroot ${chrootDir} /bin/bash rc-update add net.eth0 boot

	chroot ${chrootDir} /bin/bash rc-update del hwclock
	chroot ${chrootDir} /bin/bash rc-update add swclock boot
	
	chroot ${chrootDir} /bin/bash $(emerge --sync && emerge ntp)
	chroot ${chrootDir} /bin/bash rc-update add ntp-client boot
	chroot ${chrootDir} /bin/bash rc-update add ntpd default

	chroot ${chrootDir} /bin/bash eselect profile set 25
}

# debug
rm -f ${WD}/${IMG}
oneTimeTearDown

mkDiskImage $1
mountCpEdit
xCompile
postConfig

oneTimeTearDown


# vim:ts=2
