#!/bin/bash

set -e -o pipefail

time=$(date +%Y-%m-%d)

## Parameters
source configs/common.conf

## Board configuraions
source ${BOARD_CONFIG}/${FIRE_BOARD}.conf
source configs/user.conf


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
cp ${BUILD}/${NUBOOT_FILE}  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/uboot
cp ${BUILD}/${MUBOOT_FILE}  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/uboot
cp ${BUILD_DEBS}/${KERNEL_DEB}   ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/kernel_deb
cp deploy/${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}/${target_name}*.img  \
   ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/image

cp deploy/${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}/*rootfs* \
   ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/rootfs/${DISTRIB_TYPE}

if [ "${target_name}" == "stm32mp157" ]; then
	cp deploy/${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}/bootfs.img \
		${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/rootfs/${DISTRIB_TYPE}
else

	cp deploy/${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}/boot.tar \
		${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/rootfs/${DISTRIB_TYPE}

        if [ -f deploy/${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}/fatboot.img ]; then
                cp deploy/${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}/fatboot.img \
                        ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/rootfs/${DISTRIB_TYPE}
        fi
fi



#echo "$(date +%Y-%m-%d-%H:%M:%S)  ${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}"  >> ${ROOT}/history/history_version


echo "镜像使用说明文档："  > ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "https://doc.embedfire.com/lubancat/os_release_note/zh/latest/index.html" >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo " " >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt

echo "主机名：$rfs_hostname" >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "用户名：$rfs_username" >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "密码: $rfs_password" >>  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo " " >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt

cd $UBOOT_DIR
echo "uboot仓库：$UBOOT_SOURCE_URL " >>  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "uboot分支：$UBOOT_GIT_BRANCH " >>  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "uboot提交ID $(git log | grep commit | head -n 1 |  awk '{print $2}')" >>  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo " " >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt

cd $LINUX_DIR
echo "内核仓库：$LINUX_SOURCE_URL " >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "内核分支：$LINUX_GIT_BRANCH " >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "内核提交ID $(git log | grep commit | head -n 1 |  awk '{print $2}')" >>  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo " " >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt

cd $ROOT
echo "image-builder仓库：https://gitee.com/Embedfire/ebf-image-builder" >>  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "image-builder分支：master" >>  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo "image-builder提交ID: $(git log | grep commit | head -n 1 |  awk '{print $2}')"  >>  ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt
echo " " >> ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/镜像日志.txt


#压缩
xz -zf ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/image/${target_name}*.img

# Generate sha256sum
cd ${ROOT}/history/${target_name}/${DISTRIBUTION}/${time}/image/
sha256sum  ${target_name}*.xz > SHA256SUMS.txt
cd -

#target_name

echo -e "\nDone."
echo -e "\n`date`"

end_time=`date +%s`
time_cal $(($end_time - $start_time))

