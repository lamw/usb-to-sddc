#!/bin/bash
# William Lam
# www.virtuallyghetto.com

ESXI_ISO_PATH=/root/VMware-VMvisor-Installer-201701001-4887370.x86_64.iso
VCSA_ISO_PATH=/root/VMware-VCSA-all-6.5.0-4827210.iso
ESXI_KICKSTART_PATH=/root/usb-to-sddc/KS.CFG
DEPLOYVM_ZIP_PATH=/root/DeployVM.zip
LOG_OUTPUT=/root/script.log

if [ ! $(uname -s) == "Linux" ]; then
  echo "This script is only meant to run on Linux system"
  exit 1
fi

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root"
  exit 1
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 [USB_DEVICE]"
  echo -e "\n\t$0 /dev/sdb"
  exit
fi

USB_DEVICE=$1

echo "Please confirm that ${USB_DEVICE} is the USB Device you would like to use (Y/N)"
read RESPONSE
case "$RESPONSE" in [yY])
  ;;
  *) echo "Quiting Installer!"
  exit 1
  ;;
esac

if [ ! -e ${ESXI_ISO_PATH} ]; then
  echo "Error: ESXi ISO was not found"
  exit 1
fi

if [ ! -e ${VCSA_ISO_PATH} ]; then
  echo "Error: VCSA ISO was not found"
  exit 1
fi

if [ ! -e ${DEPLOYVM_ZIP_PATH} ]; then
  echo "Error: DeployVM zip file was not found"
  exit 1
fi

if [ ! -e ${ESXI_KICKSTART_PATH} ]; then
  echo "Error: ESXi Kickstart file was not found"
  exit 1
fi

echo "Setting up syslinux-3.86 ..."
apt-get -y install make gcc nasm unzip
wget https://www.kernel.org/pub/linux/utils/boot/syslinux/3.xx/syslinux-3.86.zip
mkdir /tmp/syslinux-3.86
mv syslinux-3.86.zip /tmp/syslinux-3.86
cd /tmp/syslinux-3.86
unzip syslinux-3.86.zip
make &> ${LOG_OUTPUT}
cd /root

echo "Clearning all existing partitions on USB Device ..."
dd if=/dev/zero of=${USB_DEVICE} bs=512 count=1

echo "Creating BOOT and PAYLOAD partition on USB Device ..."
echo "n
p
1

+2G
t
6
n
p
2


t
2
b
w
" | fdisk ${USB_DEVICE} >> ${LOG_OUTPUT}

mkdosfs -F 16 ${USB_DEVICE}1 -n BOOT >> ${LOG_OUTPUT}
mkdosfs -F 32 ${USB_DEVICE}2 -n PAYLOAD >> ${LOG_OUTPUT}
/tmp/syslinux-3.86/linux/syslinux ${USB_DEVICE}1
cat /tmp/syslinux-3.86/mbr/mbr.bin > ${USB_DEVICE}

mkdir -p /tmp/{BOOT,PAYLOAD}
mount ${USB_DEVICE}1 /tmp/BOOT
mount ${USB_DEVICE}2 /tmp/PAYLOAD

echo "Copying ESXi Installation to /tmp/BOOT ..."
mkdir -p /tmp/mnt
mount -o loop ${ESXI_ISO_PATH} /tmp/mnt
cp -r /tmp/mnt/* /tmp/BOOT
umount /tmp/mnt
rmdir /tmp/mnt
mv /tmp/BOOT/isolinux.cfg /tmp/BOOT/syslinux.cfg
sed -i s/menu.c32/mboot.c32/g /tmp/BOOT/syslinux.cfg

echo "Copying KS.cfg to /tmp/BOOT ..."
cp ${ESXI_KICKSTART_PATH} /tmp/BOOT

echo "Updating boot.cfg to use KS.cfg ..."
sed -i 's#kernelopt.*#kernelopt=ks=usb:/KS.CFG#g' /tmp/BOOT/BOOT.CFG
sed -i 's#kernelopt.*#kernelopt=ks=usb:/KS.CFG#g' /tmp/BOOT/EFI/BOOT/BOOT.CFG

echo "Copying Deploy VM zip to /tmp/PAYLOAD ..."
cp ${DEPLOYVM_ZIP_PATH} /tmp/PAYLOAD

echo "Checking to see if VCSA ISO has already been splitted into individual 1GB chunks ..."
VCSA_ISO_DIRECTORY=${VCSA_ISO_PATH%/*}
ls ${VCSA_ISO_DIRECTORY}/VCSA-part-* > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Spitting VCSA ISO into individual 1GB chunks ... "
  split -b 1073741824 ${VCSA_ISO_PATH} ${VCSA_ISO_DIRECTORY}/VCSA-part-
else
  echo "VCSA ISO has already been splitted, skipping step ..."
fi

echo "Copying VCSA chunks to /tmp/PAYLOAD ..."
cp ${VCSA_ISO_DIRECTORY}/VCSA-part-* /tmp/PAYLOAD

echo "Unmounting /tmp/{BOOT,PAYLOAD} ..."
umount /tmp/BOOT
umount /tmp/PAYLOAD
rmdir /tmp/BOOT
rmdir /tmp/PAYLOAD
