#!/bin/bash -e
#
# Copyright (c) 2009-2019 Robert Nelson <robertcnelson@gmail.com>
# Copyright (c) 2010 Mario Di Francesco <mdf-code@digitalexile.it>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Latest can be found at:
# https://github.com/RobertCNelson/omap-image-builder/blob/master/tools/setup_sdcard.sh

#REQUIREMENTS:
#uEnv.txt bootscript support

BOOT_LABEL="BOOT"

unset USE_BETA_BOOTLOADER
unset USE_LOCAL_BOOT
unset LOCAL_BOOTLOADER

#Defaults
ROOTFS_TYPE=ext4
ROOTFS_LABEL=rootfs

DIR="$PWD"
TEMPDIR=$(mktemp -d)

keep_net_alive () {
	while : ; do
		echo "syncing media... $*"
		sleep 300
	done
}
keep_net_alive & KEEP_NET_ALIVE_PID=$!
cleanup_keep_net_alive () {
	[ -e /proc/$KEEP_NET_ALIVE_PID ] && kill $KEEP_NET_ALIVE_PID
}
trap cleanup_keep_net_alive EXIT

is_element_of () {
	testelt=$1
	for validelt in $2 ; do
		[ $testelt = $validelt ] && return 0
	done
	return 1
}

#########################################################################
#
#  Define valid "--rootfs" root filesystem types.
#
#########################################################################

VALID_ROOTFS_TYPES="ext2 ext3 ext4 btrfs"

is_valid_rootfs_type () {
	if is_element_of $1 "${VALID_ROOTFS_TYPES}" ] ; then
		return 0
	else
		return 1
	fi
}

check_root () {
	if ! [ $(id -u) = 0 ] ; then
		echo "$0 must be run as sudo user or root"
		exit 1
	fi
}

find_issue () {
	check_root

	ROOTFS=$(ls "${DIR}/" | grep rootfs)
	if [ "x${ROOTFS}" != "x" ] ; then
		echo "Debug: ARM rootfs: ${ROOTFS}"
	else
		echo "Error: no armel-rootfs-* file"
		echo "Make sure your in the right dir..."
		exit
	fi

	unset has_uenvtxt
	unset check
	check=$(ls "${DIR}/" | grep uEnv.txt | grep -v post-uEnv.txt | head -n 1)
	if [ "x${check}" != "x" ] ; then
		echo "Debug: image has pre-generated uEnv.txt file"
		has_uenvtxt=1
	fi

	unset has_post_uenvtxt
	unset check
	check=$(ls "${DIR}/" | grep post-uEnv.txt | head -n 1)
	if [ "x${check}" != "x" ] ; then
		echo "Debug: image has post-uEnv.txt file"
		has_post_uenvtxt="enable"
	fi
}

check_for_command () {
	if ! which "$1" > /dev/null ; then
		echo -n "You're missing command $1"
		NEEDS_COMMAND=1
		if [ -n "$2" ] ; then
			echo -n " (consider installing package $2)"
		fi
		echo
	fi
}

detect_software () {
	unset NEEDS_COMMAND

	check_for_command mkfs.vfat dosfstools
	check_for_command wget wget
	check_for_command git git
	check_for_command partprobe parted

	if [ "x${build_img_file}" = "xenable" ] ; then
		check_for_command kpartx kpartx
	fi

	if [ "${NEEDS_COMMAND}" ] ; then
		echo ""
		echo "Your system is missing some dependencies"
		echo "Debian/Ubuntu: sudo apt-get install dosfstools git kpartx wget parted"
		echo "Fedora: yum install dosfstools dosfstools git wget"
		echo "Gentoo: emerge dosfstools git wget"
		echo ""
		exit
	fi

	unset test_sfdisk
	test_sfdisk=$(LC_ALL=C sfdisk -v 2>/dev/null | grep 2.17.2 | awk '{print $1}')
	if [ "x${test_sdfdisk}" = "xsfdisk" ] ; then
		echo ""
		echo "Detected known broken sfdisk:"
		echo "See: https://github.com/RobertCNelson/netinstall/issues/20"
		echo ""
		exit
	fi

	unset wget_version
	wget_version=$(LC_ALL=C wget --version | grep "GNU Wget" | awk '{print $3}' | awk -F '.' '{print $2}' || true)
	case "${wget_version}" in
	12|13)
		#wget before 1.14 in debian does not support sni
		echo "wget: [`LC_ALL=C wget --version | grep \"GNU Wget\" | awk '{print $3}' || true`]"
		echo "wget: [this version of wget does not support sni, using --no-check-certificate]"
		echo "wget: [http://en.wikipedia.org/wiki/Server_Name_Indication]"
		dl="wget --no-check-certificate"
		;;
	*)
		dl="wget"
		;;
	esac

	dl_continue="${dl} -c"
	dl_quiet="${dl} --no-verbose"
}

local_bootloader () {
	echo ""
	echo "Using Locally Stored Device Bootloader"
	echo "-----------------------------"
	mkdir -p ${TEMPDIR}/dl/

	if [ "${spl_name}" ] ; then
		cp ${LOCAL_SPL} ${TEMPDIR}/dl/
		SPL=${LOCAL_SPL##*/}
		echo "SPL Bootloader: ${SPL}"
	fi

	if [ "${boot_name}" ] ; then
		cp ${LOCAL_BOOTLOADER} ${TEMPDIR}/dl/
		UBOOT=${LOCAL_BOOTLOADER##*/}
		echo "UBOOT Bootloader: ${UBOOT}"
	fi
}

dl_bootloader () {
	echo ""
	echo "Downloading Device's Bootloader"
	echo "-----------------------------"
	minimal_boot="1"

	mkdir -p ${TEMPDIR}/dl/${DIST}
	mkdir -p "${DIR}/dl/${DIST}"

	${dl_quiet} --directory-prefix="${TEMPDIR}/dl/" ${conf_bl_http}/${conf_bl_listfile}

	if [ ! -f ${TEMPDIR}/dl/${conf_bl_listfile} ] ; then
		echo "error: can't connect to downloading site, retry in a few minutes..."
		exit
	fi

	boot_version=$(cat ${TEMPDIR}/dl/${conf_bl_listfile} | grep "VERSION:" | awk -F":" '{print $2}')
	if [ "x${boot_version}" != "x${minimal_boot}" ] ; then
		echo "Error: This script is out of date and unsupported..."
		echo "Please Visit: https://github.com/RobertCNelson to find updates..."
		exit
	fi

	if [ "${USE_BETA_BOOTLOADER}" ] ; then
		ABI="ABX2"
	else
		ABI="ABI2"
	fi

	if [ "${spl_name}" ] ; then
		SPL=$(cat ${TEMPDIR}/dl/${conf_bl_listfile} | grep "${ABI}:${conf_board}:SPL" | awk '{print $2}')
		${dl_quiet} --directory-prefix="${TEMPDIR}/dl/" ${SPL}
		SPL=${SPL##*/}
		echo "SPL Bootloader: ${SPL}"
	else
		unset SPL
	fi

	if [ "${boot_name}" ] ; then
		UBOOT=$(cat ${TEMPDIR}/dl/${conf_bl_listfile} | grep "${ABI}:${conf_board}:BOOT" | awk '{print $2}')
		UBOOT=${UBOOT##*/}
		echo "UBOOT Bootloader: ${UBOOT}"
	else
		unset UBOOT
	fi
}

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
		echo "dd_uboot_backup=/opt/backup/uboot/${uboot_name}" >> ${wfile}
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

	echo "" >> ${wfile}
}

drive_error_ro () {
	echo "-----------------------------"
	echo "Error: for some reason your SD card is not writable..."
	echo "Check: is the write protect lever set the locked position?"
	echo "Check: do you have another SD card reader?"
	echo "-----------------------------"
	echo "Script gave up..."

	exit
}

unmount_all_drive_partitions () {
	echo ""
	echo "Unmounting Partitions"
	echo "-----------------------------"

	NUM_MOUNTS=$(mount | grep -v none | grep "${media}" | wc -l)

##	for (i=1;i<=${NUM_MOUNTS};i++)
	for ((i=1;i<=${NUM_MOUNTS};i++))
	do
		DRIVE=$(mount | grep -v none | grep "${media}" | tail -1 | awk '{print $1}')
		umount ${DRIVE} >/dev/null 2>&1 || true
	done

	echo "Zeroing out Drive"
	echo "-----------------------------"
	dd if=/dev/zero of=${media} bs=1M count=100 || drive_error_ro
	sync
	dd if=${media} of=/dev/null bs=1M count=100
	sync
}

sfdisk_partition_layout () {
	sfdisk_options="--force --in-order --Linux --unit M"
	sfdisk_boot_startmb="${conf_boot_startmb}"
	sfdisk_boot_size_mb="${conf_boot_endmb}"
	sfdisk_var_size_mb="${conf_var_startmb}"
	if [ "x${option_ro_root}" = "xenable" ] ; then
		sfdisk_var_startmb=$(($sfdisk_boot_startmb + $sfdisk_boot_size_mb))
		sfdisk_rootfs_startmb=$(($sfdisk_var_startmb + $sfdisk_var_size_mb))
	else
		sfdisk_rootfs_startmb=$(($sfdisk_boot_startmb + $sfdisk_boot_size_mb))
	fi

	test_sfdisk=$(LC_ALL=C sfdisk --help | grep -m 1 -e "--in-order" || true)
	if [ "x${test_sfdisk}" = "x" ] ; then
		echo "log: sfdisk: 2.26.x or greater detected"
		sfdisk_options="--force ${sfdisk_gpt}"
		sfdisk_boot_startmb="${sfdisk_boot_startmb}M"
		sfdisk_boot_size_mb="${sfdisk_boot_size_mb}M"
		sfdisk_var_startmb="${sfdisk_var_startmb}M"
		sfdisk_var_size_mb="${sfdisk_var_size_mb}M"
		sfdisk_rootfs_startmb="${sfdisk_rootfs_startmb}M"
	fi

	if [ "x${option_ro_root}" = "xenable" ] ; then
		echo "sfdisk: [$(LC_ALL=C sfdisk --version)]"
		echo "sfdisk: [${sfdisk_options} ${media}]"
		echo "sfdisk: [${sfdisk_boot_startmb},${sfdisk_boot_size_mb},${sfdisk_fstype},*]"
		echo "sfdisk: [${sfdisk_var_startmb},${sfdisk_var_size_mb},,-]"
		echo "sfdisk: [${sfdisk_rootfs_startmb},,,-]"

		LC_ALL=C sfdisk ${sfdisk_options} "${media}" <<-__EOF__
			${sfdisk_boot_startmb},${sfdisk_boot_size_mb},${sfdisk_fstype},*
			${sfdisk_var_startmb},${sfdisk_var_size_mb},,-
			${sfdisk_rootfs_startmb},,,-
		__EOF__

		media_rootfs_var_partition=3
	else
		echo "sfdisk: [$(LC_ALL=C sfdisk --version)]"
		echo "sfdisk: [${sfdisk_options} ${media}]"
		echo "sfdisk: [${sfdisk_boot_startmb},${sfdisk_boot_size_mb},${sfdisk_fstype},*]"
		echo "sfdisk: [${sfdisk_rootfs_startmb},,,-]"

		LC_ALL=C sfdisk ${sfdisk_options} "${media}" <<-__EOF__
			${sfdisk_boot_startmb},${sfdisk_boot_size_mb},${sfdisk_fstype},*
			${sfdisk_rootfs_startmb},,,-
		__EOF__

	fi

	sync
}

sfdisk_single_partition_layout () {
	sfdisk_options="--force --in-order --Linux --unit M"
	sfdisk_boot_startmb="${conf_boot_startmb}"
	sfdisk_var_size_mb="${conf_var_startmb}"
	if [ "x${option_ro_root}" = "xenable" ] ; then
		sfdisk_rootfs_startmb=$(($sfdisk_boot_startmb + $sfdisk_var_size_mb))
	fi

	test_sfdisk=$(LC_ALL=C sfdisk --help | grep -m 1 -e "--in-order" || true)
	if [ "x${test_sfdisk}" = "x" ] ; then
		echo "log: sfdisk: 2.26.x or greater detected"
		sfdisk_options="--force ${sfdisk_gpt}"
		sfdisk_boot_startmb="${sfdisk_boot_startmb}M"
		sfdisk_var_size_mb="${sfdisk_var_size_mb}M"
		if [ "x${option_ro_root}" = "xenable" ] ; then
			sfdisk_rootfs_startmb="${sfdisk_rootfs_startmb}M"
		fi
	fi

	if [ "x${option_ro_root}" = "xenable" ] ; then
		echo "sfdisk: [$(LC_ALL=C sfdisk --version)]"
		echo "sfdisk: [${sfdisk_options} ${media}]"
		echo "sfdisk: [${sfdisk_boot_startmb},${sfdisk_var_size_mb},${sfdisk_fstype},*]"
		echo "sfdisk: [${sfdisk_rootfs_startmb},,,-]"

		LC_ALL=C sfdisk ${sfdisk_options} "${media}" <<-__EOF__
			${sfdisk_boot_startmb},${sfdisk_var_size_mb},${sfdisk_fstype},*
			${sfdisk_rootfs_startmb},,,-
		__EOF__

		media_rootfs_var_partition=2
	else
		echo "sfdisk: [$(LC_ALL=C sfdisk --version)]"
		echo "sfdisk: [${sfdisk_options} ${media}]"
		echo "sfdisk: [${sfdisk_boot_startmb},,${sfdisk_fstype},*]"

		LC_ALL=C sfdisk ${sfdisk_options} "${media}" <<-__EOF__
			${sfdisk_boot_startmb},,${sfdisk_fstype},*
		__EOF__

	fi

	sync
}

dd_uboot_boot () {
	unset dd_uboot
	if [ ! "x${dd_uboot_count}" = "x" ] ; then
		dd_uboot="${dd_uboot}count=${dd_uboot_count} "
	fi

	if [ ! "x${dd_uboot_seek}" = "x" ] ; then
		dd_uboot="${dd_uboot}seek=${dd_uboot_seek} "
	fi

	if [ "x${build_img_file}" = "xenable" ] ; then
		dd_uboot="${dd_uboot}conv=notrunc "
	else
		if [ ! "x${dd_uboot_conf}" = "x" ] ; then
			dd_uboot="${dd_uboot}conv=${dd_uboot_conf} "
		fi
	fi

	if [ ! "x${dd_uboot_bs}" = "x" ] ; then
		dd_uboot="${dd_uboot}bs=${dd_uboot_bs}"
	fi

	if [ "x${oem_blank_eeprom}" = "xenable" ] ; then
		uboot_blob="${blank_UBOOT}"
	else
		uboot_blob="${UBOOT}"
	fi

	echo ""
	echo "copying $(pwd)/u-boot-dtb.imx"
	cp  u-boot-dtb.imx  ${TEMPDIR}/dl/${uboot_blob}

	echo "${uboot_name}: dd if=${uboot_blob} of=${media} ${dd_uboot}"
	echo "-----------------------------"
	dd if=${TEMPDIR}/dl/${uboot_blob} of=${media} ${dd_uboot}
	echo "-----------------------------"
}

dd_spl_uboot_boot () {
	unset dd_spl_uboot
	if [ ! "x${dd_spl_uboot_count}" = "x" ] ; then
		dd_spl_uboot="${dd_spl_uboot}count=${dd_spl_uboot_count} "
	fi

	if [ ! "x${dd_spl_uboot_seek}" = "x" ] ; then
		dd_spl_uboot="${dd_spl_uboot}seek=${dd_spl_uboot_seek} "
	fi

	if [ "x${build_img_file}" = "xenable" ] ; then
			dd_spl_uboot="${dd_spl_uboot}conv=notrunc "
	else
		if [ ! "x${dd_spl_uboot_conf}" = "x" ] ; then
			dd_spl_uboot="${dd_spl_uboot}conv=${dd_spl_uboot_conf} "
		fi
	fi

	if [ ! "x${dd_spl_uboot_bs}" = "x" ] ; then
		dd_spl_uboot="${dd_spl_uboot}bs=${dd_spl_uboot_bs}"
	fi

	if [ "x${oem_blank_eeprom}" = "xenable" ] ; then
		spl_uboot_blob="${blank_SPL}"
	else
		spl_uboot_blob="${SPL}"
	fi

	echo "${spl_uboot_name}: dd if=${spl_uboot_blob} of=${media} ${dd_spl_uboot}"
	echo "-----------------------------"
	dd if=${TEMPDIR}/dl/${spl_uboot_blob} of=${media} ${dd_spl_uboot}
	echo "-----------------------------"
}

format_partition_error () {
	echo "LC_ALL=C ${mkfs} ${mkfs_partition} ${mkfs_label}"
	echo "Failure: formating partition"
	exit
}

format_partition_try2 () {
	unset mkfs_options
	if [ "x${mkfs}" = "xmkfs.ext4" ] ; then
		mkfs_options="${ext4_options}"
	fi

	echo "-----------------------------"
	echo "BUG: [${mkfs_partition}] was not available so trying [${mkfs}] again in 5 seconds..."
	partprobe ${media}
	sync
	sleep 5
	echo "-----------------------------"

	echo "Formating with: [${mkfs} ${mkfs_options} ${mkfs_partition} ${mkfs_label}]"
	echo "-----------------------------"
	LC_ALL=C ${mkfs} ${mkfs_options} ${mkfs_partition} ${mkfs_label} || format_partition_error
	sync
}

format_partition () {
	unset mkfs_options
	if [ "x${mkfs}" = "xmkfs.ext4" ] ; then
		mkfs_options="${ext4_options}"
	fi

	echo "Formating with: [${mkfs} ${mkfs_options} ${mkfs_partition} ${mkfs_label}]"
	echo "-----------------------------"
	LC_ALL=C ${mkfs} ${mkfs_options} ${mkfs_partition} ${mkfs_label} || format_partition_try2
	sync
}

format_boot_partition () {
	mkfs_partition="${media_prefix}${media_boot_partition}"

	if [ "x${conf_boot_fstype}" = "xfat" ] ; then
		mount_partition_format="vfat"
		mkfs="mkfs.vfat -F 16"
		mkfs_label="-n ${BOOT_LABEL}"
	else
		mount_partition_format="${conf_boot_fstype}"
		mkfs="mkfs.${conf_boot_fstype}"
		mkfs_label="-L ${BOOT_LABEL}"
	fi

	format_partition

	boot_drive="${conf_root_device}p${media_boot_partition}"
}

format_rootfs_partition () {
	if [ "x${option_ro_root}" = "xenable" ] ; then
		mkfs="mkfs.ext2"
	else
		mkfs="mkfs.${ROOTFS_TYPE}"
	fi
	mkfs_partition="${media_prefix}${media_rootfs_partition}"
	mkfs_label="-L ${ROOTFS_LABEL}"

	format_partition

	rootfs_drive="${conf_root_device}p${media_rootfs_partition}"

	if [ "x${option_ro_root}" = "xenable" ] ; then

		mkfs="mkfs.${ROOTFS_TYPE}"
		mkfs_partition="${media_prefix}${media_rootfs_var_partition}"
		mkfs_label="-L var"

		format_partition
		rootfs_var_drive="${conf_root_device}p${media_rootfs_var_partition}"
	fi
}

create_partitions () {
	unset bootloader_installed
	unset sfdisk_gpt

	media_boot_partition=1
	media_rootfs_partition=2

	unset ext4_options

	if [ ! "x${uboot_supports_csum}" = "xtrue" ] ; then
		#Debian Stretch, mfks.ext4 default to metadata_csum, 64bit disable till u-boot works again..
		unset ext4_options
		unset test_mke2fs
		LC_ALL=C mkfs.ext4 -V &> /tmp/mkfs
		test_mkfs=$(cat /tmp/mkfs | grep mke2fs | grep 1.43 || true)
		if [ "x${test_mkfs}" = "x" ] ; then
			unset ext4_options
		else
			ext4_options="-O ^metadata_csum,^64bit"
		fi
	fi

	echo ""
	case "${bootloader_location}" in
	fatfs_boot)
		conf_boot_endmb=${conf_boot_endmb:-"12"}

		#mkfs.fat 4.1 (2017-01-24)
		#WARNING: Not enough clusters for a 16 bit FAT! The filesystem will be
		#misinterpreted as having a 12 bit FAT without mount option "fat=16".
		#mkfs.vfat: Attempting to create a too large filesystem
		#LC_ALL=C mkfs.vfat -F 16 /dev/sdg1 -n BOOT
		#Failure: formating partition

		#When using "E" this fails, however "0xE" works fine...

		echo "Using sfdisk to create partition layout"
		echo "Version: `LC_ALL=C sfdisk --version`"
		echo "-----------------------------"
		sfdisk_partition_layout
		;;
	dd_uboot_boot)
		echo "Using dd to place bootloader on drive"
		echo "-----------------------------"
		if [ "x${bootrom_gpt}" = "xenable" ] ; then
			sfdisk_gpt="--label gpt"
		fi
		if [ "x${uboot_efi_mode}" = "xenable" ] ; then
			sfdisk_gpt="--label gpt"
		fi
		dd_uboot_boot
		bootloader_installed=1
		if [ "x${enable_fat_partition}" = "xenable" ] ; then
			conf_boot_endmb=${conf_boot_endmb:-"40"}
			conf_boot_fstype=${conf_boot_fstype:-"fat"}
			sfdisk_fstype=${sfdisk_fstype:-"0xE"}
			sfdisk_partition_layout
		else
			sfdisk_single_partition_layout
			media_rootfs_partition=1
		fi
		;;
	dd_spl_uboot_boot)
		echo "Using dd to place bootloader on drive"
		echo "-----------------------------"
		if [ "x${bootrom_gpt}" = "xenable" ] ; then
			sfdisk_gpt="--label gpt"
		fi
		if [ "x${uboot_efi_mode}" = "xenable" ] ; then
			sfdisk_gpt="--label gpt"
		fi
		dd_spl_uboot_boot
		dd_uboot_boot
		bootloader_installed=1
		if [ "x${enable_fat_partition}" = "xenable" ] ; then
			conf_boot_endmb=${conf_boot_endmb:-"40"}
			conf_boot_fstype=${conf_boot_fstype:-"fat"}
			sfdisk_fstype=${sfdisk_fstype:-"0xE"}
			sfdisk_partition_layout
		else
			if [ "x${uboot_efi_mode}" = "xenable" ] ; then
				conf_boot_endmb="16"
				conf_boot_fstype="fat"
				sfdisk_fstype="U"
				BOOT_LABEL="EFI"
				sfdisk_partition_layout
			else
				sfdisk_single_partition_layout
				media_rootfs_partition=1
			fi
		fi
		;;
	part_spl_uboot_boot)
		echo "Creating partition from layout table"
		echo "Version: `LC_ALL=C sgdisk --version`"
		echo "-----------------------------"
		. ./create_sdcard_from_flashlayout.sh
		flashlayout_and_bootloader ${media} ./hwpack/$flashlayout_tsv ${TEMPDIR}/dl
		media_boot_partition=4
		media_rootfs_partition=6
		;;
	*)
		echo "Using sfdisk to create partition layout"
		echo "Version: `LC_ALL=C sfdisk --version`"
		echo "-----------------------------"
		sfdisk_partition_layout
		;;
	esac

	echo "Partition Setup:"
	echo "-----------------------------"
	LC_ALL=C fdisk -l "${media}"
	echo "-----------------------------"

	if [ "x${build_img_file}" = "xenable" ] ; then
		media_loop=$(losetup -f || true)
		if [ ! "${media_loop}" ] ; then
			echo "losetup -f failed"
			echo "Unmount some via: [sudo losetup -a]"
			echo "-----------------------------"
			losetup -a
			echo "sudo kpartx -d /dev/loopX ; sudo losetup -d /dev/loopX"
			echo "-----------------------------"
			exit
		fi

		losetup ${media_loop} "${media}"
		kpartx -av ${media_loop}
		sleep 1
		sync
		test_loop=$(echo ${media_loop} | awk -F'/' '{print $3}')
		if [ -e /dev/mapper/${test_loop}p${media_boot_partition} ] && [ -e /dev/mapper/${test_loop}p${media_rootfs_partition} ] ; then
			media_prefix="/dev/mapper/${test_loop}p"
		else
			ls -lh /dev/mapper/
			echo "Error: not sure what to do (new feature)."
			exit
		fi
	else
		partprobe ${media}
	fi

	if [ "x${media_boot_partition}" = "x${media_rootfs_partition}" ] ; then
		mount_partition_format="${ROOTFS_TYPE}"
		format_rootfs_partition
	else
		format_boot_partition
		format_rootfs_partition
	fi
}

populate_boot () {
	echo "Populating Boot Partition"
	echo "-----------------------------"

	if [ ! -d ${TEMPDIR}/disk ] ; then
		mkdir -p ${TEMPDIR}/disk
	fi

	partprobe ${media}
	if ! mount -t ${mount_partition_format} ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk; then

		echo "-----------------------------"
		echo "BUG: [${media_prefix}${media_boot_partition}] was not available so trying to mount again in 5 seconds..."
		partprobe ${media}
		sync
		sleep 5
		echo "-----------------------------"

		if ! mount -t ${mount_partition_format} ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk; then
			echo "-----------------------------"
			echo "Unable to mount ${media_prefix}${media_boot_partition} at ${TEMPDIR}/disk to complete populating Boot Partition"
			echo "Please retry running the script, sometimes rebooting your system helps."
			echo "-----------------------------"
			exit
		fi
	fi

	lsblk | grep -v sr0
	echo "-----------------------------"

	if [ "${spl_name}" ] ; then
		if [ -f ${TEMPDIR}/dl/${SPL} ] ; then
			if [ ! "${bootloader_installed}" ] ; then
				cp -v ${TEMPDIR}/dl/${SPL} ${TEMPDIR}/disk/${spl_name}
				echo "-----------------------------"
			fi
		fi
	fi


	if [ "${boot_name}" ] ; then
		if [ -f ${TEMPDIR}/dl/${UBOOT} ] ; then
			if [ ! "${bootloader_installed}" ] ; then
				cp -v ${TEMPDIR}/dl/${UBOOT} ${TEMPDIR}/disk/${boot_name}
				echo "-----------------------------"
			fi
		fi
	fi

	if [ "x${distro_defaults}" = "xenable" ] ; then
		${dl_quiet} --directory-prefix="${TEMPDIR}/dl/" https://raw.githubusercontent.com/RobertCNelson/netinstall/master/lib/distro_defaults.scr
		cp -v ${TEMPDIR}/dl/distro_defaults.scr ${TEMPDIR}/disk/boot.scr
	fi

	if [ -f "${DIR}/ID.txt" ] ; then
		cp -v "${DIR}/ID.txt" ${TEMPDIR}/disk/ID.txt
	fi

	if [ ${has_uenvtxt} ] ; then
		cp -v "${DIR}/uEnv.txt" ${TEMPDIR}/disk/uEnv.txt
		echo "-----------------------------"
	fi

	cd ${TEMPDIR}/disk
	sync
	cd "${DIR}"/

	echo "Debug: Contents of Boot Partition"
	echo "-----------------------------"
	ls -lh ${TEMPDIR}/disk/
	du -sh ${TEMPDIR}/disk/
	echo "-----------------------------"

	sync
	sync

	umount ${TEMPDIR}/disk || true

	echo "Finished populating Boot Partition"
	echo "-----------------------------"
}

kernel_detection () {
	unset has_multi_armv7_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | grep armv7 | grep -v lpae | head -n 1)
	if [ "x${check}" != "x" ] ; then
		armv7_kernel=$(ls "${dir_check}" | grep vmlinuz- | grep armv7 | grep -v lpae | head -n 1 | awk -F'vmlinuz-' '{print $2}')
		echo "Debug: image has: v${armv7_kernel}"
		has_multi_armv7_kernel="enable"
	fi

	unset has_multi_armv7_lpae_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | grep armv7 | grep lpae | head -n 1)
	if [ "x${check}" != "x" ] ; then
		armv7_lpae_kernel=$(ls "${dir_check}" | grep vmlinuz- | grep armv7 | grep lpae | head -n 1 | awk -F'vmlinuz-' '{print $2}')
		echo "Debug: image has: v${armv7_lpae_kernel}"
		has_multi_armv7_lpae_kernel="enable"
	fi

	unset has_any_arm_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | head -n 1)
	if [ "x${check}" != "x" ] ; then
		check=$(file ${dir_check}/${check} | sed -nre 's/^.*Linux kernel ARM .*(zImage).*$/\1/p')
		if [ "x${check}" != "x" ] ; then
			arm_dt_kernel=$(ls "${dir_check}" | grep vmlinuz- | head -n 1 | awk -F'vmlinuz-' '{print $2}')
			echo "Debug: image has: v${arm_dt_kernel}"
			has_any_arm_kernel="enable"
		fi
	fi
}

kernel_select () {
	unset select_kernel
	if [ "x${conf_kernel}" = "xarmv7" ] || [ "x${conf_kernel}" = "x" ] ; then
		if [ "x${has_multi_armv7_kernel}" = "xenable" ] ; then
			select_kernel="${armv7_kernel}"
		fi
	fi

	if [ "x${conf_kernel}" = "xarmv7_lpae" ] ; then
		if [ "x${has_multi_armv7_lpae_kernel}" = "xenable" ] ; then
			select_kernel="${armv7_lpae_kernel}"
		else
			if [ "x${has_multi_armv7_kernel}" = "xenable" ] ; then
				select_kernel="${armv7_kernel}"
			fi
		fi
	fi

	if [ -z "${select_kernel}" -a "x${conf_kernel}" = "x" ] ; then
		if [ "x${has_any_arm_kernel}" = "xenable" ] ; then
			select_kernel="${arm_dt_kernel}"
		fi
	fi

	if [ "${select_kernel}" ] ; then
		echo "Debug: using: v${select_kernel}"
	else
		echo "Error: [conf_kernel] not defined [armv7_lpae,armv7,bone,ti,stm32]..."
		exit
	fi
}

populate_rootfs () {
	echo "Populating rootfs Partition"
	echo "Please be patient, this may take a few minutes, as its transfering a lot of data.."
	echo "-----------------------------"

	if [ ! -d ${TEMPDIR}/disk ] ; then
		mkdir -p ${TEMPDIR}/disk
	fi

	partprobe ${media}
	if ! mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_partition} ${TEMPDIR}/disk; then

		echo "-----------------------------"
		echo "BUG: [${media_prefix}${media_rootfs_partition}] was not available so trying to mount again in 5 seconds..."
		partprobe ${media}
		sync
		sleep 5
		echo "-----------------------------"

		if ! mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_partition} ${TEMPDIR}/disk; then
			echo "-----------------------------"
			echo "Unable to mount ${media_prefix}${media_rootfs_partition} at ${TEMPDIR}/disk to complete populating rootfs Partition"
			echo "Please retry running the script, sometimes rebooting your system helps."
			echo "-----------------------------"
			exit
		fi
	fi

	# /boot has it's own partition
	if [ ! "x${media_boot_partition}" = "x${media_rootfs_partition}" ] ; then
		mkdir ${TEMPDIR}/disk/boot || true
		if ! mount -t ${mount_partition_format} ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk/boot; then
			echo "-----------------------------"
			echo "Unable to mount ${media_prefix}${media_boot_partition} at ${TEMPDIR}/disk/boot"
			echo "Please retry running the script, sometimes rebooting your system helps."
			echo "-----------------------------"
			exit
		fi
	fi

	if [ "x${option_ro_root}" = "xenable" ] ; then

		if [ ! -d ${TEMPDIR}/disk/var ] ; then
			mkdir -p ${TEMPDIR}/disk/var
		fi

		if ! mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_var_partition} ${TEMPDIR}/disk/var; then

			echo "-----------------------------"
			echo "BUG: [${media_prefix}${media_rootfs_var_partition}] was not available so trying to mount again in 5 seconds..."
			partprobe ${media}
			sync
			sleep 5
			echo "-----------------------------"

			if ! mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_var_partition} ${TEMPDIR}/disk/var; then
				echo "-----------------------------"
				echo "Unable to mount ${media_prefix}${media_rootfs_var_partition} at ${TEMPDIR}/disk/var to complete populating rootfs Partition"
				echo "Please retry running the script, sometimes rebooting your system helps."
				echo "-----------------------------"
				exit
			fi
		fi
	fi

	if [ "x${uboot_efi_mode}" = "xenable" ] ; then

		if [ ! -d ${TEMPDIR}/disk/boot/efi ] ; then
			mkdir -p ${TEMPDIR}/disk/boot/efi
		fi

		if ! mount -t vfat ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk/boot/efi; then

			echo "-----------------------------"
			echo "BUG: [${media_prefix}${media_boot_partition}] was not available so trying to mount again in 5 seconds..."
			partprobe ${media}
			sync
			sleep 5
			echo "-----------------------------"

			if ! mount -t vfat ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk/boot/efi; then
				echo "-----------------------------"
				echo "Unable to mount ${media_prefix}${media_boot_partition} at ${TEMPDIR}/disk/boot/efi to complete populating rootfs Partition"
				echo "Please retry running the script, sometimes rebooting your system helps."
				echo "-----------------------------"
				exit
			fi
		fi
	fi

	lsblk | grep -v sr0
	echo "-----------------------------"

	if [ -f "${DIR}/${ROOTFS}" ] ; then
		if which pv > /dev/null ; then
			pv "${DIR}/${ROOTFS}" | tar --numeric-owner --preserve-permissions -xf - -C ${TEMPDIR}/disk/
		else
			echo "pv: not installed, using tar verbose to show progress"

			sudo tar --numeric-owner --preserve-permissions -xf "${DIR}/${ROOTFS}" -C ${TEMPDIR}/disk/
		fi

		echo "Transfer of data is Complete, now syncing data to disk..."
		echo "Disk Size"
		du -sh ${TEMPDIR}/disk/
		sync
		sync

		echo "-----------------------------"
		if [ -f /usr/bin/stat ] ; then
			echo "-----------------------------"
			echo "Checking [${TEMPDIR}/disk/] permissions"
			/usr/bin/stat ${TEMPDIR}/disk/
			echo "-----------------------------"
		fi

		echo "Setting [${TEMPDIR}/disk/] chown root:root"
		chown root:root ${TEMPDIR}/disk/
		echo "Setting [${TEMPDIR}/disk/] chmod 755"
		chmod 755 ${TEMPDIR}/disk/

		if [ -f /usr/bin/stat ] ; then
			echo "-----------------------------"
			echo "Verifying [${TEMPDIR}/disk/] permissions"
			/usr/bin/stat ${TEMPDIR}/disk/
		fi
		echo "-----------------------------"
	fi

	dir_check="${TEMPDIR}/disk/boot/"
	kernel_detection
	kernel_select

	if [ ! "x${uboot_eeprom}" = "x" ] ; then
		echo "board_eeprom_header=${uboot_eeprom}" > "${TEMPDIR}/disk/boot/.eeprom.txt"
	fi

	mkdir ${TEMPDIR}/disk/home/debian/.resizerootfs

	wfile="${TEMPDIR}/disk/boot/uEnv.txt"
	echo "#Docs: http://elinux.org/Beagleboard:U-boot_partitioning_layout_2.0" > ${wfile}
	echo "" >> ${wfile}

	if [ "x${kernel_override}" = "x" ] ; then
		echo "uname_r=${select_kernel}" >> ${wfile}
	else
		echo "uname_r=${kernel_override}" >> ${wfile}
	fi

	if [ "${BTRFS_FSTAB}" ] ; then
		echo "mmcrootfstype=btrfs rootwait" >> ${wfile}
	fi

	echo "#uuid=" >> ${wfile}

	if [ ! "x${dtb}" = "x" ] ; then
		echo "dtb=${dtb}" >> ${wfile}
	else

		if [ ! "x${forced_dtb}" = "x" ] ; then
			echo "dtb=${forced_dtb}" >> ${wfile}
		else
			echo "#dtb=" >> ${wfile}
		fi

		if [ "x${conf_board}" != "x" ] ; then
			echo "" >> ${wfile}
			echo "###U-Boot Overlays###" >> ${wfile}
			echo "###Documentation: http://elinux.org/Beagleboard:BeagleBoneBlack_Debian#U-Boot_Overlays" >> ${wfile}
			echo "###Master Enable" >> ${wfile}
			if [ "x${uboot_cape_overlays}" = "xenable" ] ; then
				echo "enable_uboot_overlays=1" >> ${wfile}
			else
				echo "#enable_uboot_overlays=1" >> ${wfile}
			fi
			echo "#overlay_start">> ${wfile}
			echo "" >> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-i2c1-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-i2c2-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-74hc595-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-485r1-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-485r2-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-adc1-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-btwifi-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-cam-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-can1-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-can2-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-dht11-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-ecspi3-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-hdmi-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-key-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-lcd5-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-lcd43-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-led-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-sound-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-spidev-overlay.dtbo">> ${wfile}
			echo "dtoverlay=/lib/firmware/imx-fire-uart2-overlay.dtbo">> ${wfile}
			echo "#dtoverlay=/lib/firmware/imx-fire-uart3-overlay.dtbo">> ${wfile}
			echo "" >> ${wfile}
			echo "#overlay_end">> ${wfile}

			echo "" >> ${wfile}
		fi
	fi

	cmdline="coherent_pool=1M net.ifnames=0 vt.global_cursor_default=0 quiet"

	unset kms_video

	drm_device_identifier=${drm_device_identifier:-"HDMI-A-1"}
	drm_device_timing=${drm_device_timing:-"1024x768@60e"}
	if [ "x${drm_read_edid_broken}" = "xenable" ] ; then
		cmdline="${cmdline} video=${drm_device_identifier}:${drm_device_timing}"
		echo "cmdline=${cmdline}" >> ${wfile}
		echo "" >> ${wfile}
	else
		echo "cmdline=${cmdline}" >> ${wfile}
		echo "" >> ${wfile}

		echo "#In the event of edid real failures, uncomment this next line:" >> ${wfile}
		echo "#cmdline=${cmdline} video=${drm_device_identifier}:${drm_device_timing}" >> ${wfile}
		echo "" >> ${wfile}
	fi

	echo "#Use an overlayfs on top of a read-only root filesystem:" >> ${wfile}
	echo "#cmdline=${cmdline} overlayroot=tmpfs" >> ${wfile}
	echo "" >> ${wfile}

	if [ ! "x${conf_board}" = "x" ] ; then
		if [ ! "x${has_post_uenvtxt}" = "x" ] ; then
			cat "${DIR}/post-uEnv.txt" >> ${wfile}
			echo "" >> ${wfile}
		fi

		echo "#flash_firmware=enable" >> ${wfile}


		echo "" >> ${wfile}
	
	fi

	board=${conf_board}

	echo "/boot/uEnv.txt---------------"
	cat ${wfile}
	echo "-----------------------------"

	wfile="${TEMPDIR}/disk/boot/SOC.sh"
	generate_soc


	if [ -f ${TEMPDIR}/disk/etc/systemd/logind.conf ] ; then
		
		sed ${TEMPDIR}/disk/etc/systemd/logind.conf -i -e "s/^#HandlePowerKey=poweroff/HandlePowerKey=ignore/"

	fi

	#RootStock-NG
	if [ -f ${TEMPDIR}/disk/etc/rcn-ee.conf ] ; then
		. ${TEMPDIR}/disk/etc/rcn-ee.conf

		mkdir -p ${TEMPDIR}/disk/boot/uboot || true

		wfile="${TEMPDIR}/disk/etc/fstab"
		echo "# /etc/fstab: static file system information." > ${wfile}
		echo "#" >> ${wfile}
		echo "# Auto generated by RootStock-NG: setup_sdcard.sh" >> ${wfile}
		echo "#" >> ${wfile}

		if [ "x${option_ro_root}" = "xenable" ] ; then
			echo "#With read only rootfs, we need to boot once as rw..." >> ${wfile}
			echo "${rootfs_drive}  /  ext2  noatime,errors=remount-ro  0  1" >> ${wfile}
			echo "#" >> ${wfile}
			echo "#Switch to read only rootfs:" >> ${wfile}
			echo "#${rootfs_drive}  /  ext2  noatime,ro,errors=remount-ro  0  1" >> ${wfile}
			echo "#" >> ${wfile}
			echo "${rootfs_var_drive}  /var  ${ROOTFS_TYPE}  noatime  0  2" >> ${wfile}
		else
			if [ "${BTRFS_FSTAB}" ] ; then
				echo "${rootfs_drive}  /  btrfs  defaults,noatime  0  1" >> ${wfile}
			else
				echo "${rootfs_drive}  /  ${ROOTFS_TYPE}  noatime,errors=remount-ro  0  1" >> ${wfile}
			fi
		fi
		
		echo "debugfs  /sys/kernel/debug  debugfs  mode=755,uid=root,gid=gpio,defaults  0  0" >> ${wfile}

		if [ "x${DISABLE_ETH}" != "xskip" ] ; then
			wfile="${TEMPDIR}/disk/etc/network/interfaces"
			if [ -f ${wfile} ] ; then
				echo "# This file describes the network interfaces available on your system" > ${wfile}
				echo "# and how to activate them. For more information, see interfaces(5)." >> ${wfile}
				echo "" >> ${wfile}
				echo "# The loopback network interface" >> ${wfile}
				echo "auto lo" >> ${wfile}
				echo "iface lo inet loopback" >> ${wfile}
				echo "" >> ${wfile}
				echo "# The primary network interface" >> ${wfile}

				if [ "${DISABLE_ETH}" ] ; then
					echo "#auto eth0" >> ${wfile}
					echo "#iface eth0 inet dhcp" >> ${wfile}
				else
					echo "auto eth0"  >> ${wfile}
					echo "iface eth0 inet dhcp" >> ${wfile}
				fi

				#if we have systemd & wicd-gtk, disable eth0 in /etc/network/interfaces
				if [ -f ${TEMPDIR}/disk/lib/systemd/systemd ] ; then
					if [ -f ${TEMPDIR}/disk/usr/bin/wicd-gtk ] ; then
						sed -i 's/auto eth0/#auto eth0/g' ${wfile}
						sed -i 's/allow-hotplug eth0/#allow-hotplug eth0/g' ${wfile}
						sed -i 's/iface eth0 inet dhcp/#iface eth0 inet dhcp/g' ${wfile}
					fi
				fi

				#if we have connman, disable eth0 in /etc/network/interfaces
				if [ -f ${TEMPDIR}/disk/etc/init.d/connman ] ; then
					sed -i 's/auto eth0/#auto eth0/g' ${wfile}
					sed -i 's/allow-hotplug eth0/#allow-hotplug eth0/g' ${wfile}
					sed -i 's/iface eth0 inet dhcp/#iface eth0 inet dhcp/g' ${wfile}
				fi

				echo "# Example to keep MAC address between reboots" >> ${wfile}
				echo "#hwaddress ether DE:AD:BE:EF:CA:FE" >> ${wfile}

				echo "" >> ${wfile}
				echo "# The secondary network interface" >> ${wfile}
				if [ "${DISABLE_ETH}" ] ; then
					echo "#auto eth1" >> ${wfile}
					echo "#iface eth1 inet dhcp" >> ${wfile}
				else
					echo "auto eth1"  >> ${wfile}
					echo "iface eth1 inet dhcp" >> ${wfile}
				fi

				echo "" >> ${wfile}

				echo "##connman: ethX static config" >> ${wfile}
				echo "#connmanctl services" >> ${wfile}
				echo "#Using the appropriate ethernet service, tell connman to setup a static IP address for that service:" >> ${wfile}
				echo "#sudo connmanctl config <service> --ipv4 manual <ip_addr> <netmask> <gateway> --nameservers <dns_server>" >> ${wfile}

				echo "" >> ${wfile}

				echo "##connman: WiFi" >> ${wfile}
				echo "#" >> ${wfile}
				echo "#connmanctl" >> ${wfile}
				echo "#connmanctl> tether wifi off" >> ${wfile}
				echo "#connmanctl> enable wifi" >> ${wfile}
				echo "#connmanctl> scan wifi" >> ${wfile}
				echo "#connmanctl> services" >> ${wfile}
				echo "#connmanctl> agent on" >> ${wfile}
				echo "#connmanctl> connect wifi_*_managed_psk" >> ${wfile}
				echo "#connmanctl> quit" >> ${wfile}

				echo "" >> ${wfile}

				echo "# Ethernet/RNDIS gadget (g_ether)" >> ${wfile}
				echo "# Used by: /opt/scripts/boot/autoconfigure_usb0.sh" >> ${wfile}
				echo "iface usb0 inet static" >> ${wfile}
				echo "    address 192.168.7.2" >> ${wfile}
				echo "    netmask 255.255.255.252" >> ${wfile}
				echo "    network 192.168.7.0" >> ${wfile}
				echo "    gateway 192.168.7.1" >> ${wfile}
			fi
		fi

		if [ -f ${TEMPDIR}/disk/var/www/index.html ] ; then
			rm -f ${TEMPDIR}/disk/var/www/index.html || true
		fi

		if [ -f ${TEMPDIR}/disk/var/www/html/index.html ] ; then
			rm -f ${TEMPDIR}/disk/var/www/html/index.html || true
		fi
		sync

	fi #RootStock-NG

	if [ ! "x${uboot_name}" = "x" ] ; then
		echo "Backup version of u-boot: /opt/backup/uboot/"
		mkdir -p ${TEMPDIR}/disk/opt/backup/uboot/
		cp -v ${TEMPDIR}/dl/${UBOOT} ${TEMPDIR}/disk/opt/backup/uboot/${uboot_name}
	fi

	if [ ! "x${spl_uboot_name}" = "x" ] ; then
		mkdir -p ${TEMPDIR}/disk/opt/backup/uboot/
		cp -v ${TEMPDIR}/dl/${SPL} ${TEMPDIR}/disk/opt/backup/uboot/${spl_uboot_name}
	fi

	if [ -f ${TEMPDIR}/disk/etc/init.d/cpufrequtils ] ; then
		sed -i 's/GOVERNOR="ondemand"/GOVERNOR="performance"/g' ${TEMPDIR}/disk/etc/init.d/cpufrequtils
	fi

	if [ ! -f ${TEMPDIR}/disk/opt/scripts/boot/generic-startup.sh ] ; then
		#sudo git clone https://gitee.com/wildfireteam/ebf_6ull_bootscripts.git ${TEMPDIR}/disk/opt/scripts-bak/ --depth 1
		#if [ -f ${TEMPDIR}/disk/opt/scripts/boot/ebf-build.sh ] ; then
		#	cp ${TEMPDIR}/disk/opt/scripts/boot/ebf-build.sh  ${TEMPDIR}/disk/opt/scripts-bak/boot
		#	rm -r ${TEMPDIR}/disk/opt/scripts/
		#fi
		#mv ${TEMPDIR}/disk/opt/scripts-bak ${TEMPDIR}/disk/opt/scripts/
		sudo git clone https://gitee.com/wildfireteam/ebf_6ull_bootscripts.git ${TEMPDIR}/disk/opt/scripts/ --depth 1
		sudo chown -R 1000:1000 ${TEMPDIR}/disk/opt/scripts/
	fi



	if [ "x${drm}" = "xetnaviv" ] ; then
		wfile="/etc/X11/xorg.conf"
		if [ -f ${TEMPDIR}/disk${wfile} ] ; then
			if [ -f ${TEMPDIR}/disk/usr/lib/xorg/modules/drivers/armada_drv.so ] ; then
				sudo sed -i -e 's:modesetting:armada:g' ${TEMPDIR}/disk${wfile}
				sudo sed -i -e 's:fbdev:armada:g' ${TEMPDIR}/disk${wfile}
			fi
		fi
	fi

	if [ "${usbnet_mem}" ] ; then
		echo "vm.min_free_kbytes = ${usbnet_mem}" >> ${TEMPDIR}/disk/etc/sysctl.conf
	fi

	if [ "${need_wandboard_firmware}" ] ; then
		http_brcm="https://raw.githubusercontent.com/Freescale/meta-fsl-arm-extra/master/recipes-bsp/broadcom-nvram-config/files/wandboard"
		${dl_quiet} --directory-prefix="${TEMPDIR}/disk/lib/firmware/brcm/" ${http_brcm}/brcmfmac4329-sdio.txt
		${dl_quiet} --directory-prefix="${TEMPDIR}/disk/lib/firmware/brcm/" ${http_brcm}/brcmfmac4330-sdio.txt
	fi

	if [ ! "x${new_hostname}" = "x" ] ; then
		echo "Updating Image hostname to: [${new_hostname}]"

		wfile="/etc/hosts"
		echo "127.0.0.1	localhost" > ${TEMPDIR}/disk${wfile}
		echo "127.0.1.1	${new_hostname}.localdomain	${new_hostname}" >> ${TEMPDIR}/disk${wfile}
		echo "" >> ${TEMPDIR}/disk${wfile}
		echo "# The following lines are desirable for IPv6 capable hosts" >> ${TEMPDIR}/disk${wfile}
		echo "::1     localhost ip6-localhost ip6-loopback" >> ${TEMPDIR}/disk${wfile}
		echo "ff02::1 ip6-allnodes" >> ${TEMPDIR}/disk${wfile}
		echo "ff02::2 ip6-allrouters" >> ${TEMPDIR}/disk${wfile}

		wfile="/etc/hostname"
		echo "${new_hostname}" > ${TEMPDIR}/disk${wfile}
	fi

	# setuid root ping+ping6 - capabilities does not survive tar
	if [ -x  ${TEMPDIR}/disk/bin/ping ] ; then
		echo "making ping/ping6 setuid root"
		chmod u+s ${TEMPDIR}/disk//bin/ping ${TEMPDIR}/disk//bin/ping6
	fi

	cd ${TEMPDIR}/disk/


	if [ -f ./opt/scripts/mods/debian-add-sbin-usr-sbin-to-default-path.diff ] ; then
		if [ -f /usr/bin/patch ] ; then
			echo "Patching: /etc/profile"
			patch -p1 < ./opt/scripts/mods/debian-add-sbin-usr-sbin-to-default-path.diff
		fi
	fi

	# set terminal type
	echo "export TERM=linux" > ./etc/profile.d/terminal

	# shorter networking timeout
	sed -i -re 's/^ *TimeoutStartSec=.*/TimeoutStartSec=1sec/g' ./lib/systemd/system/networking.service

	sync
	sync

	cd "${DIR}/"

	if [ ! "x${media_boot_partition}" = "x${media_rootfs_partition}" ] ; then
		umount ${TEMPDIR}/disk/boot || true
	fi


	if [  "x${media_boot_partition}" != "x${media_rootfs_partition}" ] ; then
		if ! mount -t ${mount_partition_format} ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk/mnt; then
				echo "-----------------------------"
				echo "Unable to mount ${media_prefix}${media_boot_partition} at ${TEMPDIR}/C"
				echo "Please retry running the script, sometimes rebooting your system helps."
				echo "-----------------------------"
				exit
		fi
		cp -rf ${TEMPDIR}/disk/mnt/* ${TEMPDIR}/disk/boot
	fi

	# don't change files in boot partition from now on.
	if [  "x${media_boot_partition}" != "x${media_rootfs_partition}" ] ; then
		sync
		sync
		umount ${TEMPDIR}/disk/mnt || true
	fi

	cd ${TEMPDIR}/disk
	tar -cf "${DIR}/${ROOTFS}" . 

	cd "${DIR}/"

	wfile="${TEMPDIR}/disk/etc/fstab"

	if [ "x${uboot_efi_mode}" = "xenable" ] ; then
		echo "${boot_drive}  /boot/efi vfat defaults 0 0" >> ${wfile}
	fi
	if [ ! "x${boot_drive}" = "x${rootfs_drive}" ] ; then
		echo "${boot_drive}  /boot vfat defaults 0 0" >> ${wfile}
	fi

	rm -rf ${TEMPDIR}/disk/boot/*

	if [ "x${option_ro_root}" = "xenable" ] ; then
		umount ${TEMPDIR}/disk/var || true
	fi

	if [ "x${uboot_efi_mode}" = "xenable" ] ; then
		umount ${TEMPDIR}/disk/boot/efi || true
	fi

	umount ${TEMPDIR}/disk || true
	if [ "x${build_img_file}" = "xenable" ] ; then
		sync
		kpartx -d ${media_loop} || true
		losetup -d ${media_loop} || true
	fi

	echo "Finished populating rootfs Partition"
	echo "-----------------------------"

	echo "setup_sdcard.sh script complete"
	if [ -f "${DIR}/user_password.list" ] ; then
		echo "-----------------------------"
		echo "The default user:password for this image:"
		cat "${DIR}/user_password.list"
		echo "-----------------------------"
	fi
	if [ "x${build_img_file}" = "xenable" ] ; then
		echo "Image file: ${imagename}"
		echo "-----------------------------"
	fi
}

check_mmc () {
	FDISK=$(LC_ALL=C fdisk -l 2>/dev/null | grep "Disk ${media}:" | awk '{print $2}')

	if [ "x${FDISK}" = "x${media}:" ] ; then
		echo ""
		echo "I see..."
		echo ""
		echo "lsblk:"
		lsblk | grep -v sr0
		echo ""
		unset response
		echo -n "Are you 100% sure, on selecting [${media}] (y/n)? "
		read response
		if [ "x${response}" != "xy" ] ; then
			exit
		fi
		echo ""
	else
		echo ""
		echo "Are you sure? I Don't see [${media}], here is what I do see..."
		echo ""
		echo "lsblk:"
		lsblk | grep -v sr0
		echo ""
		exit
	fi
}

process_dtb_conf () {
	if [ "${conf_warning}" ] ; then
		show_board_warning
	fi

	echo "-----------------------------"

	#defaults, if not set...
	case "${bootloader_location}" in
	fatfs_boot)
		conf_boot_startmb=${conf_boot_startmb:-"1"}
		;;
	dd_uboot_boot|dd_spl_uboot_boot)
		conf_boot_startmb=${conf_boot_startmb:-"4"}
		;;
	*)
		conf_boot_startmb=${conf_boot_startmb:-"4"}
		;;
	esac

	#https://wiki.linaro.org/WorkingGroups/KernelArchived/Projects/FlashCardSurvey
	conf_root_device=${conf_root_device:-"/dev/mmcblk0"}

	#error checking...
	if [ ! "${conf_boot_fstype}" ] ; then
		conf_boot_fstype="${ROOTFS_TYPE}"
	fi

	case "${conf_boot_fstype}" in
	fat)
		sfdisk_fstype=${sfdisk_fstype:-"0xE"}
		;;
	ext2|ext3|ext4|btrfs)
		sfdisk_fstype="L"
		;;
	*)
		echo "Error: [conf_boot_fstype] not recognized, stopping..."
		exit
		;;
	esac

	if [ "x${uboot_cape_overlays}" = "xenable" ] ; then
		echo "U-Boot Overlays Enabled..."
	fi
}

check_dtb_board () {
	error_invalid_dtb=1

	#/hwpack/${dtb_board}.conf
	unset leading_slash
	leading_slash=$(echo ${dtb_board} | grep "/" || unset leading_slash)
	if [ "${leading_slash}" ] ; then
		dtb_board=$(echo "${leading_slash##*/}")
	fi

	#${dtb_board}.conf
	dtb_board=$(echo ${dtb_board} | awk -F ".conf" '{print $1}')
	if [ -f "${DIR}"/hwpack/${dtb_board}.conf ] ; then
		. "${DIR}"/hwpack/${dtb_board}.conf

		boot=${boot_image}
		unset error_invalid_dtb
		process_dtb_conf
	else
		cat <<-__EOF__
			-----------------------------
			ERROR: This script does not currently recognize the selected: [--dtb ${dtb_board}] option..
			Please rerun $(basename $0) with a valid [--dtb <device>] option from the list below:
			-----------------------------
		__EOF__
		cat "${DIR}"/hwpack/*.conf | grep supported
		echo "-----------------------------"
		exit
	fi
}

usage () {
	echo "usage: sudo $(basename $0) --mmc /dev/sdX --dtb <dev board>"
	#tabed to match 
		cat <<-__EOF__
			-----------------------------
			Bugs email: "bugs at rcn-ee.com"

			Required Options:
			--mmc </dev/sdX> or --img <filename.img>

			--dtb <dev board>

			Additional Options:
			        -h --help

			--probe-mmc
			        <list all partitions: sudo ./setup_sdcard.sh --probe-mmc>

			__EOF__
	exit
}

checkparm () {
	if [ "$(echo $1|grep ^'\-')" ] ; then
		echo "E: Need an argument"
		usage
	fi
}

error_invalid_dtb=1

# parse commandline options
while [ ! -z "$1" ] ; do
	case $1 in
	-h|--help)
		usage
		media=1
		;;
	--hostname)
		checkparm $2
		new_hostname="$2"
		;;
	--probe-mmc)
		media="/dev/idontknow"
		check_root
		check_mmc
		;;
	--mmc)
		checkparm $2
		media="$2"
		media_prefix="${media}"
		echo ${media} | grep mmcblk >/dev/null && media_prefix="${media}p"
		check_root
		check_mmc
		;;
	--img|--img-[12468]gb)
		checkparm $2
		name=${2:-image}
		gsize=$(echo "$1" | sed -ne 's/^--img-\([[:digit:]]\+\)gb$/\1/p')
		# --img defaults to --img-2gb
		gsize=${gsize:-2}
		imagename=${name%.img}-${gsize}gb.img
		media="${DIR}/${imagename}"
		build_img_file="enable"
		check_root
		if [ -f "${media}" ] ; then
			rm -rf "${media}" || true
		fi
		#FIXME: (should fit most microSD cards)
		#eMMC: (dd if=/dev/mmcblk1 of=/dev/null bs=1M #MB)
		#Micron   3744MB (bbb): 3925868544 bytes -> 3925.86 Megabyte
		#Kingston 3688MB (bbb): 3867148288 bytes -> 3867.15 Megabyte
		#Kingston 3648MB (x15): 3825205248 bytes -> 3825.21 Megabyte (3648)
		#
		### seek=$((1024 * (700 + (gsize - 1) * 1000)))
		## 1000 1GB = 700 #2GB = 1700 #4GB = 3700
		##  990 1GB = 700 #2GB = 1690 #4GB = 3670
		#
		### seek=$((1024 * (gsize * 850)))
		## x 850 (85%) #1GB = 850 #2GB = 1700 #4GB = 3400
		##pure 170
		#qts 210
		#xfce4 500
		#qtd 450
		dd if=/dev/zero of="${media}" bs=1024 count=0 seek=$((1024 * (gsize * 190)))
		;;
	--dtb)
		checkparm $2
		dtb_board="$2"
		dir_check="${DIR}/"
		kernel_detection
		check_dtb_board
		;;
	--ro)
		conf_var_startmb="2048"
		option_ro_root="enable"
		;;
	--rootfs)
		checkparm $2
		ROOTFS_TYPE="$2"
		;;
	--boot_label)
		checkparm $2
		BOOT_LABEL="$2"
		;;
	--rootfs_label)
		checkparm $2
		ROOTFS_LABEL="$2"
		;;
	--spl)
		checkparm $2
		LOCAL_SPL="$2"
		USE_LOCAL_BOOT=1
		;;
	--bootloader)
		checkparm $2
		LOCAL_BOOTLOADER="$2"
		USE_LOCAL_BOOT=1
		;;
	--use-beta-bootloader)
		USE_BETA_BOOTLOADER=1
		;;
	--bbb-usb-flasher|--usb-flasher|--oem-flasher)
		oem_blank_eeprom="enable"
		usb_flasher="enable"
		;;
	--bbb-flasher|--emmc-flasher)
		oem_blank_eeprom="enable"
		emmc_flasher="enable"
		uboot_eeprom="bbb_blank"
		;;
	--bbb-old-bootloader-in-emmc)
		echo "[--bbb-old-bootloader-in-emmc] is obsolete, and has been removed..."
		exit 2
		;;
	--x15-force-revb-flash)
		x15_force_revb_flash="enable"
		;;
	--am57xx-x15-flasher)
		flasher_uboot="beagle_x15_flasher"
		;;
	--am57xx-x15-revc-flasher)
		flasher_uboot="beagle_x15_revc_flasher"
		;;
	--am571x-sndrblock-flasher)
		flasher_uboot="am571x_sndrblock_flasher"
		;;
	--oem-flasher-script)
		checkparm $2
		oem_flasher_script="$2"
		;;
	--oem-flasher-img)
		checkparm $2
		oem_flasher_img="$2"
		;;
	--oem-flasher-eeprom)
		checkparm $2
		oem_flasher_eeprom="$2"
		;;
	--oem-flasher-job)
		checkparm $2
		oem_flasher_job="$2"
		;;
	--enable-systemd)
		echo "--enable-systemd: option is depreciated (enabled by default Jessie+)"
		;;
	--enable-uboot-cape-overlays)
		uboot_cape_overlays="enable"
		;;
	--efi)
		uboot_efi_mode="enable"
		;;
	--offline)
		offline=1
		;;
	--kernel)
		checkparm $2
		kernel_override="$2"
		;;
	--enable-cape)
		checkparm $2
		oobe_cape="$2"
		;;
	--enable-fat-partition)
		enable_fat_partition="enable"
		;;
	--force-device-tree)
		checkparm $2
		forced_dtb="$2"
		;;
	esac
	shift
done

if [ ! "${media}" ] ; then
	echo "ERROR: --mmc undefined"
	usage
fi

if [ "${error_invalid_dtb}" ] ; then
	echo "-----------------------------"
	echo "ERROR: --dtb undefined"
	echo "-----------------------------"
	usage
fi

if ! is_valid_rootfs_type ${ROOTFS_TYPE} ; then
	echo "ERROR: ${ROOTFS_TYPE} is not a valid root filesystem type"
	echo "Valid types: ${VALID_ROOTFS_TYPES}"
	exit
fi

unset BTRFS_FSTAB
if [ "x${ROOTFS_TYPE}" = "xbtrfs" ] ; then
	unset NEEDS_COMMAND
	check_for_command mkfs.btrfs btrfs-tools

	if [ "${NEEDS_COMMAND}" ] ; then
		echo ""
		echo "Your system is missing the btrfs dependency needed for this particular target."
		echo "Ubuntu/Debian: sudo apt-get install btrfs-tools"
		echo "Fedora: as root: yum install btrfs-progs"
		echo "Gentoo: emerge btrfs-progs"
		echo ""
		exit
	fi

	BTRFS_FSTAB=1

	if [ ! "x${conf_boot_fstype}" = "xfat" ] ; then
		conf_boot_fstype="btrfs"
	fi
fi

find_issue
detect_software

if [ "${spl_name}" ] || [ "${boot_name}" ] ; then
	if [ "${USE_LOCAL_BOOT}" ] ; then
		local_bootloader
	else
		dl_bootloader
	fi
fi

if [ ! "x${build_img_file}" = "xenable" ] ; then
	unmount_all_drive_partitions
fi
create_partitions
populate_boot
populate_rootfs
exit 0
#
