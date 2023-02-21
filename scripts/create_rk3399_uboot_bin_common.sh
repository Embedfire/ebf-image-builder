#!/bin/bash -e


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
        echo "job is "${NR_JOBS}
		${BUILD_SCRIPT_OF_UBOOT} -j${NR_JOBS} ${UBOOT_CONFIG}
        ${BUILD_SCRIPT_OF_UBOOT} -j${NR_JOBS} CROSS_COMPILE=${UBOOT_COMPILER} BL31=${ROOT}/rkbin/bin/rk33/rk3399_bl31_v1.35.elf
fi


dd if=idbloader.img of=$MUBOOT_FILE seek=64 conv=notrunc
dd if=u-boot.itb of=$MUBOOT_FILE seek=16384 conv=notrunc
cp $MUBOOT_FILE ${BUILD}/${MUBOOT_FILE}