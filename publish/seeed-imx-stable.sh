#!/bin/bash -e

time=$(date +%Y-%m-%d)
DIR="$PWD"

ssh_svr=192.168.13.13
ssh_user="seeeder@${ssh_svr}"
rev=$(git rev-parse HEAD)
branch=$(git describe --contains --all HEAD)
server_dir="/home/public/share/imx6ull"
this_name=$0

#export apt_proxy=localhost:3142/

Usage() {
	echo "Usage：sudo ./publish/seeed-imx-stable.sh [option]"
	echo "Optiong："
	echo "          lite ：Build a pure version of debian image"
	echo "          qts  ：Build a static qt libary of debian image"
	echo "          qtd  ：Build a dynamic qt libary of debian image"
	echo "          xfce4：Build a debian image with xfec4"		
	echo "Example：sudo ./publish/seeed-imx-stable.sh lite"	
}

keep_net_alive () {
	while : ; do
		sleep 15
		echo "log: [Running: ${this_name}]"
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

case $1 in
lite)
	img_type="console"
	other_pk=" "
	alloc_size=218
;;
qts) 
	img_type="part-qt-app"
	other_pk="qt-app-static-build"
	alloc_size=230
;;
qtd) 
	img_type="full-qt-app"
	other_pk="qt-app"
	alloc_size=470
;;
xfec4)
	img_type="desktop"
	other_pk="xfce4"
	alloc_size=520	
;;
*) Usage
   exit
;;
esac 


export other_pk
export alloc_size

trap "kill_net_alive;" EXIT

build_and_upload_image () {
	full_name=${target_name}-${image_name}-${size}
	echo "***BUILDING***: ${config_name}: ${full_name}.img"

	# To prevent rebuilding:
	# export FULL_REBUILD=
	FULL_REBUILD=${FULL_REBUILD-1}
	if [ -n "${FULL_REBUILD}" -o ! -e "deploy/${image_name}.tar" ]; then
		./RootStock-NG.sh -c ${config_name}
	fi

	if [ -d ./deploy/${image_name} ] ; then
		cd ./deploy/${image_name}/
		echo "debug: [./imxv7_setup_sdcard.sh ${options}]"
		sudo -E ./imxv7_setup_sdcard.sh ${options}

		if [ -f ${full_name}.img ] ; then
			me=`whoami`
			sudo chown ${me}.${me} ${full_name}.img
			if [ -f "${full_name}.img.xz.job.txt" ]; then
				sudo chown ${me}.${me} ${full_name}.img.xz.job.txt
			fi

			sync ; sync ; sleep 5
#			sudo xz -k6 -T50 ${full_name}.img
			# TODO
			# sudo rm -rf ./deploy/ || true
		else
			echo "***ERROR***: Could not find ${full_name}.img"
		fi
	else
		echo "***ERROR***: Could not find ./deploy/${image_name}"
	fi
}

keep_net_alive & KEEP_NET_ALIVE_PID=$!
echo "pid: [${KEEP_NET_ALIVE_PID}]"

# Console i.MX6ULL image
##Debian 10:
#image_name="${deb_distribution}-${release}-${image_type}-${deb_arch}-${time}"
image_name="debian-buster-console-armhf-${time}"
size="2gb"
target_name="imx6ull"
options="--img-2gb ${target_name}-${image_name} --dtb imx6ull --enable-fat-partition"
options="${options} --enable-uboot-cape-overlays --force-device-tree imx6ull-seeed-npi.dtb "

config_name="seeed-imx-debian-buster-console-v4.19"
# using temperary bootloader
# options="${options} --bootloader /home/pi/packages/u-boot/u-boot-dtb.imx"
build_and_upload_image




##Ubuntu 18.04
: <<\EOF
#image_name="${deb_distribution}-${release}-${image_type}-${deb_arch}-${time}"
image_name="ubuntu-18.04.2-console-armhf-${time}"
size="2gb"
target_name="imx6ull"
options="--img-2gb ${target_name}-${image_name} --dtb imx6ull --enable-fat-partition"
options="${options} --enable-uboot-cape-overlays --force-device-tree imx6ull-seeed-npi.dtb"
# options="${options} --bootloader /home/pi/packages/u-boot/u-boot-dtb.imx"
config_name="seeed-imx-ubuntu-bionic-console-v4.19"
build_and_upload_image
EOF

kill_net_alive
