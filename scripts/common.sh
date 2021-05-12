generate_soc () {
	echo "#!/bin/sh" > ${wfile}
	echo "format=1.0" >> ${wfile}
	echo "" >> ${wfile}
	if [ ! "x${conf_bootloader_in_flash}" = "xenable" ] ; then
		echo "board=${board}" >> ${wfile}
		echo "" >> ${wfile}
		echo "bootloader_location=${bootloader_location}" >> ${wfile}
		echo "bootrom_gpt=${bootrom_gpt}" >> ${wfile}
		echo "" >> ${wfile}
		echo "dd_spl_uboot_count=${dd_spl_uboot_count}" >> ${wfile}
		echo "dd_spl_uboot_seek=${dd_spl_uboot_seek}" >> ${wfile}
		if [ "x${build_img_file}" = "xenable" ] ; then
			echo "dd_spl_uboot_conf=notrunc" >> ${wfile}
		else
			echo "dd_spl_uboot_conf=${dd_spl_uboot_conf}" >> ${wfile}
		fi
		echo "dd_spl_uboot_bs=${dd_spl_uboot_bs}" >> ${wfile}
		if [ ! "x${spl_uboot_name}" = "x" ] ; then
			echo "dd_spl_uboot_backup=/opt/backup/uboot/${spl_uboot_name}" >> ${wfile}
		else
			echo "dd_spl_uboot_backup=" >> ${wfile}
		fi
		echo "" >> ${wfile}
		echo "dd_uboot_count=${dd_uboot_count}" >> ${wfile}
		echo "dd_uboot_seek=${dd_uboot_seek}" >> ${wfile}
		if [ "x${build_img_file}" = "xenable" ] ; then
			echo "dd_uboot_conf=notrunc" >> ${wfile}
		else
			echo "dd_uboot_conf=${dd_uboot_conf}" >> ${wfile}
		fi
		echo "dd_uboot_bs=${dd_uboot_bs}" >> ${wfile}
		echo "dd_uboot_emmc_backup=/opt/backup/uboot/${MUBOOT_FILE}" >> ${wfile}
		echo "dd_uboot_nand_backup=/opt/backup/uboot/${NUBOOT_FILE}" >> ${wfile}
	else
		echo "uboot_CONFIG_CMD_BOOTZ=${uboot_CONFIG_CMD_BOOTZ}" >> ${wfile}
		echo "uboot_CONFIG_SUPPORT_RAW_INITRD=${uboot_CONFIG_SUPPORT_RAW_INITRD}" >> ${wfile}
		echo "uboot_CONFIG_CMD_FS_GENERIC=${uboot_CONFIG_CMD_FS_GENERIC}" >> ${wfile}
		echo "zreladdr=${conf_zreladdr}" >> ${wfile}
	fi
	echo "" >> ${wfile}
	echo "boot_fstype=${conf_boot_fstype}" >> ${wfile}
	echo "conf_boot_startmb=${conf_boot_startmb}" >> ${wfile}
	echo "conf_boot_endmb=${conf_boot_endmb}" >> ${wfile}
	echo "sfdisk_fstype=${sfdisk_fstype}" >> ${wfile}
	echo "" >> ${wfile}
    echo "conf_root_device=${conf_root_device:-/dev/mmcblk0}" >> ${wfile}
    echo "" >> ${wfile}
	if [ "x${uboot_efi_mode}" = "xenable" ] ; then
		echo "uboot_efi_mode=${uboot_efi_mode}" >> ${wfile}
		echo "" >> ${wfile}
	fi

	echo "boot_label=${BOOT_LABEL}" >> ${wfile}
	echo "rootfs_label=${ROOTFS_LABEL}" >> ${wfile}
	echo "" >> ${wfile}
	echo "#Kernel" >> ${wfile}
	echo "dtb=${dtb}" >> ${wfile}
	echo "serial_tty=${SERIAL}" >> ${wfile}
	echo "usbnet_mem=${usbnet_mem}" >> ${wfile}
	echo "" >> ${wfile}
	echo "#Advanced options" >> ${wfile}
	echo "#disable_ssh_regeneration=true" >> ${wfile}
	echo "${FlashLayout_NAND}" >> ${wfile}
	
	echo "" >> ${wfile}

	echo "${FlashLayout_EMMC}" >> ${wfile}
	
	echo "" >> ${wfile}	
}