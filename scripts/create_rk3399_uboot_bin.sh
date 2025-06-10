#!/bin/bash -e
[ -n "$BUILD_DEBUG" ] && set -x


if [ ! "$SCRIPT_URL" == "" ]; then
    if [ ! -d $ROOT/${SCRIPT_DIR}/.git ]; then
		info_msg "U-boot script repository does not exist, clone u-boot script repository from '$SCRIPT_DIR'..."
		cd $ROOT
		git clone $SCRIPT_URL
		cd $UBOOT_DIR
	fi
fi

if [ ! "$BUILD_SCRIPT_OF_UBOOT" == "" ]; then
		mkdir -p ${BUILD}
		. $BUILD_SCRIPT_OF_UBOOT evb-rk3399
fi

tools/mkimage -n rk3399 -T rksd -d ../rkbin/bin/rk33/rk3399_ddr_800MHz_v1.25.bin idbloader.img
cat ../rkbin/bin/rk33/rk3399_miniloader_v1.26.bin >> idbloader.img

dd if=idbloader.img of=$MUBOOT_FILE seek=64
dd if=uboot.img of=$MUBOOT_FILE seek=16384
dd if=trust.img of=$MUBOOT_FILE seek=24576

cp $MUBOOT_FILE ${BUILD}/${MUBOOT_FILE}
