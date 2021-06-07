## image-builder_2.0 构建镜像过程

[TOC]

### 设置板级配置文件

##### env/setenv.sh

```
#选择flash类型
	INSTALL_TYPE_ARRAY=("ALL" "NAND" "eMMC/SD")
	choose_install_type
#选择开发板型号
	choose_fire_board
#选择uboot版本(板级配置文件 SUPPORTED_UBOOT=("2020.10"))
	choose_uboot_version
#选择uboot tag
	choose_uboot_tag
	choose_linux_version
	choose_linux_tag
#选择发行版系统
	choose_distribution
	choose_distribution_release
	choose_distribution_type
```

##### env/ci_imx6.sh

```
#自动构建用，替代手动配置
FIRE_BOARD=ebf_imx_6ull_pro
LINUX=4.19.35
UBOOT=2020.10
DISTRIBUTION=Debian
DISTRIB_RELEASE=buster
DISTRIB_TYPE=console
INSTALL_TYPE=ALL
```

#### 板级配置文件

configs/boards/ebf_imx_6ull_pro.conf

```
uboot\kernel
架构\sd镜像信息
镜像偏移信息
设备树插件
```



### 编译uboot、kernel、kernel-deb

##### 主makefile

```
#全部构建
all:
ifeq ($(and $(DISTRIBUTION),$(DISTRIB_RELEASE),$(DISTRIB_TYPE),$(DISTRIB_ARCH),$(FIRE_BOARD),$(LINUX),$(UBOOT),$(INSTALL_TYPE)),)
	$(call help_message)
else
	@./scripts/create_image.sh
endif

#构建内核
kernel:
...
	@./scripts/build.sh linux


#构建uboot
uboot:
...
	@./scripts/build.sh u-boot

#构建内核deb包
kernel-deb:
	@./scripts/build.sh linux-deb

```

#### create_image.sh

###### 构建全部固件

```
./scripts/build.sh u-boot 
./scripts/build.sh linux
./scripts/build.sh linux-deb
```

###### 构建根文件系统需要密码

```
read PASSWORD
echo "$PASSWORD" | sudo -E -S $ROOT/publish/fire-imx-stable.sh
```

###### 记录编译时长

```
start_time=`date +%s`
end_time=`date +%s`
time_cal $(($end_time - $start_time))
```

#### build.sh

###### 导入板级配置和全局配置

```
source configs/common.conf

source ${BOARD_CONFIG}/${FIRE_BOARD}.conf

```

###### 编译uboot、kernel、kernel-deb的具体函数

```
case "$TARGET" in
	u-boot)
		build_uboot
		;;
	linux)
		build_linux
		;;
	linux-deb)
		build_linux_debs
		;;
esac
```

###### 编译过程

```
git clone/fetch 拉取分支
git checkout 切换分支
make distclean 清楚编译文件
make xxx_config
make

#uboot需要单独备份到文件系统以供sd卡烧录
cp ${UBOOT_BUILD_FILE} ${BUILD}/${MUBOOT_FILE}
```



### 抽取debian官方根文件系统

##### publish/fire-imx-stable.sh

###### 后台运行监控信息

```
keep_net_alive () {
	while : ; do
		sleep 15
		info_msg "[Running: ${this_name}]"
	done
}
```

##### build_fire_image

###### 抽取debian根文件系统

```
if [ -n "${FULL_REBUILD}" -o ! -e "deploy/${image_name}.tar" ]; then
		. ${BUILD_SCRIPT}/RootStock-NG.sh -c ${BOARD_CONFIG}/${FIRE_BOARD}.conf
	fi
	
sudo -E ./${chroot_custom_setup_sdcard} ${options}
```

##### RootStock-NG.sh

###### 创建临时文件夹\设置image名字

```
tempdir=$(mktemp -d -p ${DIR}/ignore)
time=$(date +%Y-%m-%d)
export_filename="${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}"
```

##### install_dependencies.sh

###### 安装qemu、git、kpartx、debootstrap等镜像构建工具

##### debootstrap.sh

###### 根据common.com全局配置文件的信息，抽取debian文件系统，存放于临时文件夹

```
target=tempdir

sudo debootstrap --no-merged-usr ${options} ${suite} "${target}" ${mirror} 
```

##### chroot.sh

###### 复制qumu到临时文件夹，启动debian，加入定制内容

```

sudo cp $(which qemu-arm-static) "${tempdir}/usr/bin/"

sudo chroot "${tempdir}" debootstrap/debootstrap --second-stage

#设置镜像源、用户密码、开机启动服务等等
...

#安装内核deb包和自定义deb包
sudo chroot "${tempdir}" /bin/bash -e chroot_script.sh

install_pkgs ()
dpkg -i /tmp/*.deb
```

###### 根据临时文件夹大小估算镜像大小

```
sys_size="$(du -sh ${DIR}/deploy/${export_filename} 2>/dev/null | awk '{print $1}')"

image_size=$(bc -l <<< "scale=0; ((($value * 1.2) / 1 + 0) / 4 + 1) * 4")

mkfifo -m 777 /tmp/npipe
echo "$image_size" > /tmp/npipe &
```

###### 打包根文件系统

```
cd "${DIR}/deploy/" || true
sudo tar cvf ${export_filename}.tar ./${export_filename}
sudo chown -R ${USER}:${USER} "${export_filename}.tar"
```



### 构建空白镜像，填充uboot，根文件系统

##### tools/imxv7_setup_sdcard.sh

###### dd构建镜像

```
--img|--img-[12468]gb)
	read msize < /tmp/npipe
	imagename=${name%.img}.img
	media="${DIR}/${imagename}"
	dd if=/dev/zero of="${media}" bs=1024 count=0 seek=$((1024 * msize))
```

###### dd填充uboot

```
选择uboot

local_bootloader
	if [ "${boot_name}" ] ; then
		cp  ${LOCAL_BOOT_PATH}/${NUBOOT_FILE} ${TEMPDIR}/dl/
		cp  ${LOCAL_BOOT_PATH}/${MUBOOT_FILE} ${TEMPDIR}/dl/
		U_BOOT=${MUBOOT_FILE}
		echo "U_BOOT Bootloader: ${U_BOOT}"
	fi
	
	cp -v ${TEMPDIR}/dl/${NUBOOT_FILE} 		           		             ${TEMPDIR}/disk/opt/backup/uboot/${NUBOOT_FILE}
	
填充uboot并将镜像分区
create_partitions
	dd_uboot_boot
	1、dd if=${TEMPDIR}/dl/${uboot_blob} of=${media} ${dd_uboot}
	2、
	losetup ${media_loop} "${media}"
    kpartx -av ${media_loop}
    sleep 1
    sync
    test_loop=$(echo ${media_loop} | awk -F'/' '{print $3}')
    if [ -e /dev/mapper/${test_loop}p${media_boot_partition} ] && [ 	-e /dev/mapper/${test_loop}p${media_rootfs_partition} ] ; then
    media_prefix="/dev/mapper/${test_loop}p"
    else
    ls -lh /dev/mapper/
    echo "Error: not sure what to do (new feature)."
    exit
    fi
    
挂载uboot分区、rootf分区并填充根文件系统
	populate_rootfs
		1、mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_partition} ${TEMPDIR}/disk
		2、mount -t ${mount_partition_format} ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk/boot
		3、sudo tar --numeric-owner --preserve-permissions -xf "${DIR}/${ROOTFS}" -C ${TEMPDIR}/disk/
		4、调整uEnv.txt等
		wfile="${TEMPDIR}/disk/boot/uEnv.txt"
		...
```



