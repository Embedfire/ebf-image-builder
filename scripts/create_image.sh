#!/bin/bash

set -e -o pipefail

time=$(date +%Y-%m-%d)

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

## 历史编译目录
mkdir -p history/${target_name}/${DISTRIBUTION}/${time}/image
mkdir -p history/${target_name}/${DISTRIBUTION}/${time}/uboot
mkdir -p history/${target_name}/${DISTRIBUTION}/${time}/kernel_deb 
mkdir -p history/${target_name}/${DISTRIBUTION}/${time}/rootfs/${DISTRIB_TYPE}
mkdir -p history/tempdir/$(date +%Y-%m)/${DISTRIBUTION}/${DISTRIB_RELEASE}

if [ "$USER" != 'root' ]; then
	echo "Building rootfs stage requires root privileges, please enter your passowrd:"
	read PASSWORD
else
	PASSWORD=
fi


#build tfa
if [ ! -f ${BUILD}/${TFA_BUILD_FILE} -o ! -f ${BUILD}/${TFA_BUILD_FILE} -o "x${FORCE_UPDATE}" = "xenable" ]; then
		if [ ! -z ${TFA_BUILD_FILE} ]; then
			./scripts/build.sh tfa
		fi
fi

#build uboot
if [ ! -f ${BUILD}/${MUBOOT_FILE} -a ! -f ${BUILD}/${NUBOOT_FILE} -o "x${FORCE_UPDATE}" = "xenable" ]; then
		./scripts/build.sh u-boot 
fi

#build kernel
if [ ! -f ${BUILD_DEBS}/${KERNEL_DEB} -o "x${FORCE_UPDATE}" = "xenable" ]; then
		./scripts/build.sh linux
		./scripts/build.sh linux-deb
fi

## Rootfs stage requires root privileges
echo "$PASSWORD" | sudo -E -S $ROOT/publish/fire-imx-stable.sh



#编译输出
cp ${BUILD}/${NUBOOT_FILE}  history/${target_name}/${DISTRIBUTION}/${time}/uboot
cp ${BUILD}/${MUBOOT_FILE}  history/${target_name}/${DISTRIBUTION}/${time}/uboot
cp ${BUILD_DEBS}/${KERNEL_DEB}   history/${target_name}/${DISTRIBUTION}/${time}/kernel_deb
cp deploy/${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}/*.img  \
   history/${target_name}/${DISTRIBUTION}/${time}/image

cp deploy/${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}/*rootfs* \
   history/${target_name}/${DISTRIBUTION}/${time}/rootfs/${DISTRIB_TYPE}

echo "$(date +%Y-%m-%d-%H:%M:%S)  ${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}"  >> history/history_version





echo -e "\nDone."
echo -e "\n`date`"

end_time=`date +%s`
time_cal $(($end_time - $start_time))

