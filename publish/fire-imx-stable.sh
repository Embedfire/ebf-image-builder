#!/bin/bash -e

#global config
source configs/common.conf

#board config
source ${BOARD_CONFIG}/${FIRE_BOARD}.conf

##common functions
source configs/functions/functions

DIR="$PWD"
this_name=$0

keep_net_alive () {
	while : ; do
		sleep 15
		info_msg "[Running: ${this_name}]"
	done
}

kill_net_alive() {
	[ -e /proc/$KEEP_NET_ALIVE_PID ] && {
		# TODO
		# sudo rm -rf ./deploy/ || true
		sudo kill $KEEP_NET_ALIVE_PID
	}
	return 0;
}

echo "*****$deb_arch******"

trap "kill_net_alive;" EXIT
USE_LOCAL_BOOT="yes"
build_fire_image () {
	full_name=${target_name}-${image_name}
	info_msg "***BUILDING***: ${FIRE_BOARD}: ${full_name}.img"

	# To prevent rebuilding:
	# export FULL_REBUILD=
	FULL_REBUILD=${FULL_REBUILD-1}
	if [ -n "${FULL_REBUILD}" -o ! -e "deploy/${image_name}.tar" ]; then
		. ${BUILD_SCRIPT}/RootStock-NG.sh -c ${BOARD_CONFIG}/${FIRE_BOARD}.conf
	fi

	if [ -d ${ROOT}/deploy/${image_name} ] ; then
		cd ${ROOT}/deploy/${image_name}/
		info_msg "debug: [${ROOT}/${chroot_custom_setup_sdcard} ${options}]"
		sudo -E ./${chroot_custom_setup_sdcard} ${options}
	else
		info_msg "***ERROR***: Could not find ${ROOT}/deploy/${image_name}"
		exit -1
	fi

	if [ -n "${NEED_EXT4_IMG}" ]; then
		info_msg "debug: do_ext4_img"

		cd ${ROOT}/deploy/${image_name}/
		tmp_dir=$(mktemp -d  tmp.XXXXXXXXXX)
		rootfs_dir=$(mktemp -d  tmp.XXXXXXXXXX)
		sudo tar -xvf armhf-rootfs-debian-buster.tar -C ${tmp_dir}

		file_size=$(du -sb ${tmp_dir} | awk '{print $1}')
		file_size_b=$(($file_size+52428800+52428800+52428800+52428800+52428800+52428800+52428800))
#		sudo rm -rf ${tmp_dir}/dev/*
#		sudo make_ext4fs -l 512M rootfs.ext4 ${tmp_dir}
		sudo dd if=/dev/zero of=rootfs.img bs=${file_size_b} count=1
		sudo mkfs.ext4 rootfs.img
		
		sudo mount rootfs.img ${rootfs_dir}
		sudo rsync -aAx --human-readable --info=name0,progress2 ${tmp_dir}/* ${rootfs_dir}
		
		sudo echo "# /etc/fstab: static file system information." > ${rootfs_dir}/etc/fstab
		sudo echo "#" >> ${rootfs_dir}/etc/fstab
		sudo echo "/dev/mmcblk1p2 /boot auto defaults 0 0" >> ${rootfs_dir}/etc/fstab
		sudo echo "/dev/mmcblk1p4 /  ext4  noatime,errors=remount-ro  0  1" >> ${rootfs_dir}/etc/fstab
		sudo echo "debugfs  /sys/kernel/debug  debugfs  defaults  0  0" >> ${rootfs_dir}/etc/fstab

		sudo rm -rf ${rootfs_dir}/home/debian/.resizerootfs
		sudo touch ${rootfs_dir}/home/debian/.resizerootfs
		sudo umount ${rootfs_dir}

		sudo dd if=/dev/zero of=bootfs.img bs=1024 count=102400
		sudo mkfs.vfat bootfs.img
		bootfs_dir=$(mktemp -d  tmp.XXXXXXXXXX)

		sudo mount bootfs.img ${bootfs_dir}
		img_file=$(cd ${ROOT}/deploy/${image_name}/ && ls *debian-buster*.img)

		media_loop=$(sudo losetup -f || true)
		sudo losetup ${media_loop} ${img_file}
		sudo kpartx -av ${media_loop}
		test_loop=$(echo ${media_loop} | awk -F'/' '{print $3}')
		sudo mount /dev/mapper/${test_loop}p4 ${rootfs_dir}

		sudo rsync -aAxv ${rootfs_dir}/* ${bootfs_dir}
		sudo umount ${bootfs_dir}
		sudo umount ${rootfs_dir}
		sync
		kpartx -d ${media_loop} || true
		losetup -d ${media_loop} || true
	
		sudo rm -rdf ${tmp_dir}
		sudo rm -rdf ${bootfs_dir}
		sudo rm -rdf ${rootfs_dir}
	fi

	exit 0
}

keep_net_alive & KEEP_NET_ALIVE_PID=$!
echo "pid: [${KEEP_NET_ALIVE_PID}]"

build_fire_image

kill_net_alive
