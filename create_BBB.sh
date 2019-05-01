#!/bin/sh

DISK=da0
ROOTFS=/mnt/rootfs
KERNEL=GENERIC-NODEBUG
MSDOSFS=${ROOTFS}/boot/msdos

confirm() {
read -p "$1 [Y/n] " yn
case $yn in
    [YyJj]* | "" )
        return 0
        ;;
    *)
        return 1
        ;;
esac

}

if [ "$(df | grep -c ${DISK})" != "0" ]; then
    echo Unmounting /dev/${DISK}s2a
    echo umount /dev/${DISK}s2a
fi

confirm  "Delete Partition Table of ${DISK}?"
if [ "$?" == 0 ]; then
    echo Delete partition table for disk /dev/${DISK}
    echo gpart destroy -F ${DISK}
fi

confirm  "Setup new Partition Table for ${DISK}?"
if [ "$?" == 0 ]; then
    echo Setup disk /dev/${DISK}
    echo gpart create -s MBR ${DISK}
    echo gpart add -t '!12' -a 512k -s 50m ${DISK}
    echo gpart set -a active -i 1 ${DISK}
    echo newfs_msdos -L msdosboot -F 16 /dev/${DISK}s1
    echo gpart add -t freebsd ${DISK}
    echo gpart create -s bsd ${DISK}s2
    echo gpart add -t freebsd-ufs -a 64k /dev/${DISK}s2
    echo newfs -U -L rootfs /dev/${DISK}s2a
fi
 
echo Create Rootfs and mount it
echo mkdir -p ${ROOTFS}
echo mount /dev/${DISK}s2a ${ROOTFS}
 
confirm  "Install world and kernel into ${ROOTFS}?"
if [ "$?" == 0 ]; then
    echo Installing world and kernel into ${ROOTFS}
    echo make -C /usr/src \
        TARGET=arm \
        TARGET_ARCH=armv7 \
        DESTDIR=${ROOTFS} \
        KERNCONF=${KERNEL} \
        installworld installkernel distribution
fi
 
confirm  "Generate Files as fstab and rc.conf"
if [ "$?" == 0 ]; then

echo Generate fstab
cat << EOF >> ${ROOTFS}/etc/fstab
/dev/ufs/rootfs / ufs rw 1 1
/dev/msdosfs/MSDOSBOOT /boot/msdos msdosfs rw,noatime 0 0
tmpfs /tmp tmpfs rw,mode=1777,size=50m 0  0
EOF

echo Generate rc.conf
hostname="$(echo ${KERNEL} | tr '[:upper:]' '[:lower:]')"
cat << EOF >> ${ROOTFS}/etc/rc.conf
hostname="${hostname}"
ifconfig_DEFAULT="DHCP"
sshd_enable="YES"
sendmail_enable="NONE"
sendmail_submit_enable="NO"
sendmail_outbound_enable="NO"
sendmail_msp_queue_enable="NO"
growfs_enable="YES"
EOF

echo Generate fstab
cat << EOF >> ${ROOTFS}/etc/fstab
/dev/ufs/rootfs / ufs rw 1 1
/dev/msdosfs/MSDOSBOOT /boot/msdos msdosfs rw,noatime 0 0
tmpfs /tmp tmpfs rw,mode=1777,size=50m 0  0
EOF

echo loader.conf
cat << EOF >> ${ROOTFS}/boot/loader.conf
# DTB OVERLAYS
# fdt_overlays="example.dtbo,example2.dtbo"
EOF
fi

confirm  "Create and mount dosfs into /boot?"
if [ "$?" == 0 ]; then
    echo Create Boot folder and mount it
    mkdir -p ${MSDOSFS}
    mount -t msdosfs /dev/${DISK}s1 ${MSDOSFS}

    echo Copy ubldr and u-boot
    cp -p ${ROOTFS}/boot/ubldr.bin ${MSDOSFS}/ubldr.bin
    mkdir -p ${MSDOSFS}/EFI/BOOT
    cp -p /usr/obj/usr/src/arm.armv7/stand/efi/loader_lua/loader_lua.efi ${MSDOSFS}/EFI/BOOT/bootarm.efi
    cp -R ${ROOTFS}/boot/dtb ${MSDOSFS}

    cp -P /usr/local/share/u-boot/u-boot-beaglebone/MLO ${MSDOSFS}
    cp -P /usr/local/share/u-boot/u-boot-beaglebone/u-boot.img ${MSDOSFS}
fi


confirm  "Umount all?"
if [ "$?" == 0 ]; then
    umount ${MSDOSFS}
    umount ${ROOTFS}
fi

