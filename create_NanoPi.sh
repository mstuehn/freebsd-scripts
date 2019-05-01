#!/bin/sh

DISK=da0
ROOTFS=/mnt/rootfs
KERNEL=GENERIC-NODEBUG
MSDOSFS=${ROOTFS}/boot/msdos
BOOTLOADER=/usr/local/share/u-boot/u-boot-nanopi-neo2/u-boot-sunxi-with-spl.bin

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
    umount /dev/${DISK}s2a
fi

confirm  "Delete Partition Table of ${DISK}?"
if [ "$?" == 0 ]; then
    echo Delete partition table for disk /dev/${DISK}
    gpart destroy -F ${DISK}
fi

confirm  "Setup new Partition Table for ${DISK}?"
if [ "$?" == 0 ]; then
    echo Setup disk /dev/${DISK}
    gpart create -s MBR ${DISK}
    gpart add -b 1M -t fat32lba -a 512k -s 50m ${DISK}
    gpart set -a active -i 1 ${DISK}
    newfs_msdos -L msdosboot -F 16 /dev/${DISK}s1
    gpart add -t freebsd ${DISK}
    gpart create -s bsd ${DISK}s2
    gpart add -t freebsd-ufs -a 64k /dev/${DISK}s2
    newfs -U -L aarch64rootfs /dev/${DISK}s2a
fi

confirm "Install bootloader into ${DISK}"
if [ "$?" == 0 ]; then
    dd if=${BOOTLOADER} of=/dev/${DISK} bs=1k seek=8 conv=sync
fi

echo Create Rootfs and mount it
mkdir -p ${ROOTFS}
mount /dev/${DISK}s2a ${ROOTFS}

confirm  "Install world and kernel into ${ROOTFS}?"
if [ "$?" == 0 ]; then
    echo Installing world and kernel into ${ROOTFS}
    make -C /usr/src \
        TARGET=arm64 \
        TARGET_ARCH=aarch64 \
        DESTDIR=${ROOTFS} \
        KERNCONF=${KERNEL} \
        installworld installkernel distribution
fi

confirm  "Generate Files as fstab and rc.conf"
if [ "$?" == 0 ]; then

echo Generate fstab
cat << EOF >> ${ROOTFS}/etc/fstab
/dev/ufs/aarch64rootfs / ufs rw 1 1
#/dev/msdosfs/MSDOSBOOT /boot/msdos msdosfs ro,noatime 0 0
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
#growfs_enable="YES"
EOF

echo loader.conf
cat << EOF >> ${ROOTFS}/boot/loader.conf
#vfs.root.mountfrom="ufs:/dev/mmcsd0s2"

# load correct devicetree
sun50i-h5-nanopi-neo2_load="YES"
sun50i-h5-nanopi-neo2_type="dtb"
sun50i-h5-nanopi-neo2_name="sun50i-h5-nanopi-neo2.dtb"
# DTB OVERLAYS
# fdt_overlays="example.dtbo,example2.dtbo"
fdt_overlays="sun50i-nanopi-neo2-sid,sun50i-nanopi-neo2-ths.dtbo,sun50i-nanopi-neo2-nanohat.dtbo"
EOF
fi

confirm  "Create dosfs and prepare EFI?"
if [ "$?" == 0 ]; then
    echo Create Boot folder and mount it
    mkdir -p ${MSDOSFS}
    mount -t msdosfs /dev/${DISK}s1 ${MSDOSFS}

    echo Copy ubldr and u-boot
    mkdir -p ${MSDOSFS}/EFI/BOOT
    cp -p ${ROOTFS}/boot/loader.efi ${MSDOSFS}/EFI/BOOT/bootaa64.efi
    umount ${MSDOSFS}
fi


confirm  "Umount all?"
if [ "$?" == 0 ]; then
    umount ${ROOTFS}
fi

