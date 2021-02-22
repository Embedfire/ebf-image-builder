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
		sudo -E ${BUILD_SCRIPT}/RootStock-NG.sh -c ${BOARD_CONFIG}/${FIRE_BOARD}.conf
	fi

	if [ -d ${ROOT}/deploy/${image_name} ] ; then
		cd ${ROOT}/deploy/${image_name}/
		info_msg "debug: [${ROOT}/${chroot_custom_setup_sdcard} ${options}]"
		sudo -E ./${chroot_custom_setup_sdcard} ${options}
	else
		info_msg "***ERROR***: Could not find ${ROOT}/deploy/${image_name}"
		exit -1
	fi

}

keep_net_alive & KEEP_NET_ALIVE_PID=$!
echo "pid: [${KEEP_NET_ALIVE_PID}]"

build_fire_image

kill_net_alive
