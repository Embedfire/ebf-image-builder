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

trap "kill_net_alive;" EXIT
USE_LOCAL_BOOT="yes"
build_fire_image () {
	full_name=${target_name}-${image_name}-${size}
	info_msg "***BUILDING***: ${FIRE_BOARD}: ${full_name}.img"

	# To prevent rebuilding:
	# export FULL_REBUILD=
	FULL_REBUILD=${FULL_REBUILD-1}
	if [ -n "${FULL_REBUILD}" -o ! -e "deploy/${image_name}.tar" ]; then
		${BUILD_SCRIPT}/RootStock-NG.sh -c ${BOARD_CONFIG}/${FIRE_BOARD}.conf
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
		which make_ext4fs  >/dev/null 2>&1
		if [ $? -eq 1 ];then
			info_msg "***ERROR***: Please run 'sudo apt install android-tools-fsutils'"
			exit -1
		fi
		cd ${ROOT}/deploy/${image_name}/
		tmp_dir=$(mktemp -d  tmp.XXXXXXXXXX)
		rootfs_dir=$(mktemp -d  tmp.XXXXXXXXXX)
		sudo tar -xvf armhf-rootfs-debian-buster.tar -C ${tmp_dir}
#		sudo rm -rf ${tmp_dir}/dev/*
#		sudo make_ext4fs -l 512M rootfs.ext4 ${tmp_dir}
		sudo dd if=/dev/zero of=rootfs.img bs=512 count=1048576
		sudo mkfs.ext4 rootfs.img
		
		sudo mount rootfs.img ${rootfs_dir}
		sudo cp -rdf ${tmp_dir}/* ${rootfs_dir}
		sudo umount ${rootfs_dir}

		sudo dd if=/dev/zero of=bootfs.img bs=1024 count=24576
		sudo mkfs.vfat bootfs.img
		boot_dir=$(mktemp -d  tmp.XXXXXXXXXX)
		sudo mount bootfs.img ${boot_dir}
		sudo cp -rdf  ${tmp_dir}/boot/* ${boot_dir}
		sudo umount ${boot_dir}

		sudo rm -rdf ${tmp_dir}
		sudo rm -rdf ${boot_dir}
		sudo rm -rdf ${root_dir}
	fi

	exit 0
}

keep_net_alive & KEEP_NET_ALIVE_PID=$!
echo "pid: [${KEEP_NET_ALIVE_PID}]"

build_fire_image

kill_net_alive
