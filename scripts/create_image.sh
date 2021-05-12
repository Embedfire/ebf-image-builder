#!/bin/bash

set -e -o pipefail

## Parameters
source configs/common.conf

## Board configuraions
source ${BOARD_CONFIG}/${FIRE_BOARD}.conf

##common functions
source configs/functions/functions
######################################################################################
## Try to update Fenix
check_update() {
	cd $ROOT

	update_git_repo "$PWD" ${FENIX_BRANCH:- master}
}

#if [ "x${INSTALL_TYPE}" != "xALL" ] ; then
#	error_msg "UBOOT INSTALL TYPE must be ALL!"
#	exit 0
#fi

start_time=`date +%s`

if [ "$USER" != 'root' ]; then
	echo "Building rootfs stage requires root privileges, please enter your passowrd:"
	read PASSWORD
else
	PASSWORD=


#build tfa
if [ ! -f ${BUILD}/${TFA_BUILD_FILE} -o ! -f ${BUILD}/${TFA_BUILD_FILE} -o "x${FORCE_UPDATE}" = "xenable" ]; then
		./scripts/build.sh tfa
fi

#build uboot
if [ ! -f ${BUILD}/${MUBOOT_FILE} -a ! -f ${BUILD}/${MUBOOT_FILE} -o "x${FORCE_UPDATE}" = "xenable" ]; then
		./scripts/build.sh u-boot 
fi

#build kernel
if [ ! -f ${BUILD_DEBS}/${KERNEL_DEB} -o "x${FORCE_UPDATE}" = "xenable" ]; then
		./scripts/build.sh linux
		./scripts/build.sh linux-deb
fi

## Rootfs stage requires root privileges
echo "$PASSWORD" | sudo -E -S $ROOT/publish/fire-imx-stable.sh

echo -e "\nDone."
echo -e "\n`date`"

end_time=`date +%s`
time_cal $(($end_time - $start_time))