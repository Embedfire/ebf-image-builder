#!/bin/bash -e

if [ ! "$SCRIPT_URL" == "" ]; then
    if [ ! -d ${SCRIPT_DIR}/.git ]; then
		info_msg "U-boot script repository does not exist, clone u-boot script repository from '$SCRIPT_DIR'..."
		git clone $SCRIPT_URL
	fi
fi
cp -v ${BUILD}/${MUBOOT_FILE} ebf-imx-mkimage/iMX8M
cp -v spl/${SPL_BUILD_FILE} ebf-imx-mkimage/iMX8M
cp -v arch/arm/dts/${UBOOT_DTB} ebf-imx-mkimage/iMX8M

cd ebf-imx-mkimage

#make SOC=iMX8MM flash_spl_uboot
make SOC=iMX8MM flash_ddr4_evk_no_hdmi
cp iMX8M/flash.bin ${BUILD}/${MUBOOT_FILE}