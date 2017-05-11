#!/bin/bash
# William Lam
# www.virtuallyghetto.com

UNETBOOTIN_APP_PATH=/Users/lamw/Desktop/unetbootin.app
ESXI_ISO_PATH=/Volumes/Storage/Images/Current/VMware-VMvisor-Installer-201701001-4887370.x86_64.iso
VCSA_ISO_PATH=/Volumes/Storage/Images/Current/VMware-VCSA-all-6.5.0-4827210.iso
ESXI_KICKSTART_PATH=/Users/lamw/git/usb-to-sddc/KS.CFG
DEPLOYVM_ZIP_PATH=/Volumes/Storage/DeployVM/Photon/DeployVM.zip

if [ ! $(uname -s) == "Darwin" ]; then
  echo "This script is only meant to run on macOS system"
  exit 1
fi

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root"
  exit 1
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 [USB_DEVICE]"
  echo -e "\n\t$0 /dev/disk4"
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

if [ ! -d ${UNETBOOTIN_APP_PATH} ]; then
  echo "Error: Unetbootin App was not found"
  exit 1
fi

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

echo "Creating BOOT and PAYLOAD partition on USB Device ..."
diskutil partitionDisk ${USB_DEVICE} 2 MBRFormat "MS-DOS FAT16" BOOT 2GB "MS-DOS" PAYLOAD R

"${UNETBOOTIN_APP_PATH}/Contents/MacOS/unetbootin" lang=en method=diskimage isofile=${ESXI_ISO_PATH} installtype=USB targetdrive=${USB_DEVICE}s1 autoinstall=yes

echo "Copying KS.cfg to /Volumes/BOOT ..."
cp ${ESXI_KICKSTART_PATH} /Volumes/BOOT

echo "Updating boot.cfg to use KS.cfg ..."
sed -i .bak 's#kernelopt.*#kernelopt=ks=usb:/KS.CFG#g' /Volumes/BOOT/BOOT.CFG
sed -i .bak 's#kernelopt.*#kernelopt=ks=usb:/KS.CFG#g' /Volumes/BOOT/EFI/BOOT/BOOT.CFG
rm -f /Volumes/BOOT/BOOT.CFG.bak
rm -f /Volumes/BOOT/EFI/BOOT/BOOT.CFG.bak

echo "Copying Deploy VM zip to /Volumes/PAYLOAD ..."
cp ${DEPLOYVM_ZIP_PATH} /Volumes/PAYLOAD

echo "Checking to see if VCSA ISO has already been splitted into individual 1GB chunks ..."
VCSA_ISO_DIRECTORY=${VCSA_ISO_PATH%/*}
ls ${VCSA_ISO_DIRECTORY}/VCSA-part-* > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo "Spitting VCSA ISO into individual 1GB chunks ... "
  split -b 1073741824 ${VCSA_ISO_PATH} ${VCSA_ISO_DIRECTORY}/VCSA-part-
else
  echo "VCSA ISO has already been splitted, skipping step ..."
fi

echo "Copying VCSA chunks to /Volumes/PAYLOAD ..."
cp ${VCSA_ISO_DIRECTORY}/VCSA-part-* /Volumes/PAYLOAD

echo "Unmounting /Volumes/{BOOT,PAYLOAD} ..."
diskutil unmountDisk /Volumes/BOOT
