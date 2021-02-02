# Generate boot.scr.uimg:
# ./tools/mkimage -C none -A arm -T script -d boot.scr.cmd boot.scr.uimg
#
#########################################################################
# SAMPLE BOOT SCRIPT: PLEASE DON'T USE this SCRIPT in REAL PRODUCT
#########################################################################
# this script is only a OpenSTLinux helper to manage multiple target with the
# same bootfs, for real product with only one supported configuration change the
# bootcmd in U-boot or use the normal path for extlinux.conf to use DISTRO
# boocmd (generic distibution); U-Boot searches with boot_prefixes="/ /boot/":
# - /extlinux/extlinux.conf
# - /boot/extlinux/extlinux.conf
#########################################################################

echo "Executing SCRIPT on target=${target}"

# M4 Firmware load
env set m4fw_name "rproc-m4-fw.elf"
env set m4fw_addr ${kernel_addr_r}
env set boot_m4fw 'rproc init; rproc load 0 ${m4fw_addr} ${filesize}; rproc start 0'

# boot M4 Firmware when available
env set scan_m4fw 'if test -e ${devtype} ${devnum}:${distro_bootpart} ${m4fw_name};then echo Found M4 FW $m4fw_name; if load ${devtype} ${devnum}:${distro_bootpart} ${m4fw_addr} ${m4fw_name}; then run boot_m4fw; fi; fi;'

# Update the DISTRO command to search in sub-directory and load M4 firmware
env set boot_prefixes "/${boot_device}${boot_instance}_"
env set boot_extlinux "run scan_m4fw;${boot_extlinux}"

# save the boot config for the 2nd boot
env set boot_targets ${target}

# when {boot_device} = nor, use ${target} = the location of U-Boot
# script boot.scr.img found in DISTRO script
# value can be "mmc0" (SD Card), "mmc1" (eMMC) or "ubifs0" (NAND)

if test ${target} = mmc0; then
    if test -d ${devtype} ${devnum}:${distro_bootpart} /mmc0_extlinux; then
        env set boot_prefixes "/mmc0_"
    fi
elif test ${target} = mmc1; then
    if test -d ${devtype} ${devnum}:${distro_bootpart} /mmc1_extlinux; then
        env set boot_prefixes "/mmc1_"
    fi
elif test ${target} = ubifs0; then
    if test -d ${devtype} ${devnum}:${distro_bootpart} /nand0_extlinux; then
        env set boot_prefixes "/nand0_"
    fi
fi

if test -e ${devtype} ${devnum}:${distro_bootpart} ${boot_prefixes}extlinux/${board_name}_extlinux.conf; then
    echo FOUND ${boot_prefixes}extlinux/${board_name}_extlinux.conf
    env set boot_syslinux_conf "extlinux/${board_name}_extlinux.conf"
fi

# don't save the updated content of bootfile variable to avoid conflict
env delete bootfile

# save the boot config the 2nd boot (boot_prefixes/boot_extlinux)
#env save

# 
echo Checking for: /uEnv.txt ...;
if test -e ${devtype} ${devnum}:${distro_bootpart} /uEnv.txt;then
    if load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /uEnv.txt; then 
    echo Loaded environment from /uEnv.txt;
    echo Importing environment from ${devtype} ...; 
    env import -t ${kernel_addr_r} ${filesize}
		env set size 0x${filesize}
    fi
fi
echo Checking if flash_firmware is set;
if test -n ${flash_firmware}; then 
    echo setting flash firmware...;
    setenv cmdline ${storage_media};
fi;

#load base fdt
echo Checking for: /dtbs/4.19.94-imx-r1/stm32mp157a-basic.dtb ...;
if test -e ${devtype} ${devnum}:${distro_bootpart} /dtbs/4.19.94-imx-r1/stm32mp157a-basic.dtb;then
	echo Loading base fdt...;
	load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/4.19.94-imx-r1/stm32mp157a-basic.dtb
fi;

if test -n ${enable_uboot_overlays}; then 
	setenv fdt_buffer 0x60000;
	if test -n ${uboot_fdt_buffer}; then 
		setenv fdt_buffer ${uboot_fdt_buffer};
	fi;
	if test ${target} = ubifs0; then
        #mount rootfs
		ubifsmount ubi0:rootfs
	fi;
	echo uboot_overlays: [fdt_buffer=${fdt_buffer}] ... ;
	dtfile ${fdt_addr_r} ${splashimage} /boot/uEnv.txt ${kernel_addr_r};
else 
	echo uboot_overlays: add [enable_uboot_overlays=1] to /boot/uEnv.txt to enable...;
fi;

env set fdt_addr ${fdt_addr_r}

# start the correct exlinux.conf
run bootcmd_${target}

echo SCRIPT FAILED... ${boot_prefixes}${boot_syslinux_conf} not found !

# restore environment to default value when failed
env default boot_targets
env default boot_prefixes
env default boot_extlinux
env default boot_syslinux_conf
env save
