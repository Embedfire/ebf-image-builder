#!/bin/bash

set -e -o pipefail


IMAGE_BUILDER_DIR=/opt/ebf-image-builder
TARGET_DIR=/mnt/share

GIT_CLONE_OPTIONS="--depth=1"
#IMAGE_BUILDER_GIT_TAGS=master
IMAGE_BUILDER_GIT_TAGS=origin/image-builder-imx8mmini
IMAGE_BUILDER_SOURCE_URL="git@gitlab.embedfire.local:i.mx6/ebf-image-builder.git"

build_cpu=$1

source configs/functions/functions

start_time=`date +%s`

export FIRE_BOARD=
export LINUX=
export UBOOT=
export DISTRIBUTION=
export DISTRIB_RELEASE=
export DISTRIB_TYPE=
export INSTALL_TYPE=
export SUPPORTED_TFA=
export TFA=

imx6ull_build_img(){

    rebuild=$1

    #编译镜像 debian console
    FIRE_BOARD=ebf_imx_6ull_pro
    LINUX=4.19.35
    UBOOT=2020.10
    DISTRIBUTION=Debian
    DISTRIB_RELEASE=buster
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china  FORCE_UPDATE=$rebuild

    #编译镜像 debian qt
    FIRE_BOARD=ebf_imx_6ull_pro
    LINUX=4.19.35
    UBOOT=2020.10
    DISTRIBUTION=Debian
    DISTRIB_RELEASE=buster
    DISTRIB_TYPE=qt
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 

    #ubuntu18.04  console
    FIRE_BOARD=ebf_imx_6ull_pro
    LINUX=4.19.35
    UBOOT=2020.10
    DISTRIBUTION=Ubuntu
    DISTRIB_RELEASE=bionic
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 

    #ubuntu20.04  console
    FIRE_BOARD=ebf_imx_6ull_pro
    LINUX=4.19.35
    UBOOT=2020.10
    DISTRIBUTION=Ubuntu
    DISTRIB_RELEASE=focal
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 

}

stm32mp157_build_img(){

    #编译镜像 debian console
    rebuild=$1

    FIRE_BOARD=ebf_stm_mp157_star
    TFA=v2.0  
    LINUX=4.19.94
    UBOOT=2018.11
    DISTRIBUTION=Debian
    DISTRIB_RELEASE=buster
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china  FORCE_UPDATE=$rebuild

    #编译镜像 debian qt
    FIRE_BOARD=ebf_stm_mp157_star
    TFA=v2.0  
    LINUX=4.19.94
    UBOOT=2018.11
    DISTRIBUTION=Debian
    DISTRIB_RELEASE=buster
    DISTRIB_TYPE=qt
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 


    #ubuntu18.04  console
    FIRE_BOARD=ebf_stm_mp157_star
    TFA=v2.0  
    LINUX=4.19.94
    UBOOT=2018.11
    DISTRIBUTION=Ubuntu
    DISTRIB_RELEASE=bionic
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 

    #ubuntu20.04  console
    FIRE_BOARD=ebf_stm_mp157_star
    TFA=v2.0  
    LINUX=4.19.94
    UBOOT=2018.11
    DISTRIBUTION=Ubuntu
    DISTRIB_RELEASE=focal
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 

}

rk3328_build_img(){

    rebuild=$1

    #编译镜像 debian console
    FIRE_BOARD=ebf_rockchip_3328
    LINUX=5.10.25
    UBOOT=2017.09
    DISTRIBUTION=Debian
    DISTRIB_RELEASE=buster
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china FORCE_UPDATE=$rebuild

:<<qt
    #编译镜像 debian qt
    FIRE_BOARD=ebf_rockchip_3328
    LINUX=5.10.25
    UBOOT=2017.09
    DISTRIBUTION=Debian
    DISTRIB_RELEASE=buster
    DISTRIB_TYPE=qt
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 
qt
    #ubuntu18.04  console
    FIRE_BOARD=ebf_rockchip_3328
    LINUX=5.10.25
    UBOOT=2017.09
    DISTRIBUTION=Ubuntu
    DISTRIB_RELEASE=bionic
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 

    #ubuntu20.04  console
    FIRE_BOARD=ebf_rockchip_3328
    LINUX=5.10.25
    UBOOT=2017.09
    DISTRIBUTION=Ubuntu
    DISTRIB_RELEASE=focal
    DISTRIB_TYPE=console
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china 
}  

imx8mmini_build_img(){

    # imx8mmini debian10 console
    # FIRE_BOARD=ebf_imx_8m_mini
    # LINUX=5.4.47
    # UBOOT=2020.04
    # DISTRIBUTION=Debian
    # DISTRIB_RELEASE=buster
    # DISTRIB_TYPE=console
    # INSTALL_TYPE=ALL
    # make  DOWNLOAD_MIRROR=china SOURCE_URL=gitlab

    # imx8mmini debian10 xfce
    FIRE_BOARD=ebf_imx_8m_mini
    LINUX=5.4.47
    UBOOT=2020.04
    DISTRIBUTION=Debian
    DISTRIB_RELEASE=buster
    DISTRIB_TYPE=xfce
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china SOURCE_URL=gitlab

    # imx8mmini debian11 xfce
    FIRE_BOARD=ebf_imx_8m_mini
    LINUX=5.4.47
    UBOOT=2020.04
    DISTRIBUTION=Debian
    DISTRIB_RELEASE=buster
    DISTRIB_TYPE=xfce
    INSTALL_TYPE=ALL
    make  DOWNLOAD_MIRROR=china SOURCE_URL=gitlab
}

if [ ! -d ${IMAGE_BUILDER_DIR}/.git ]; then
    info_msg "Image-builder  repository does not exist, clone image-builder repository('$1') from '$IMAGE_BUILDER_SOURCE_URL'..."
    ## Clone u-boot from Khadas GitHub

    git clone $GIT_CLONE_OPTIONS $IMAGE_BUILDER_SOURCE_URL -b $IMAGE_BUILDER_GIT_TAGS $IMAGE_BUILDER_DIR
    [ $? != 0 ] && error_msg "Failed to clone 'image-builder'" && return -1

fi

cd $IMAGE_BUILDER_DIR

#拉取image-builder更新
git fetch --all
git reset --hard $IMAGE_BUILDER_GIT_TAGS
git pull

if [  $build_cpu ]; then

    echo "需要编译的芯片为$build_cpu"
    case $build_cpu in
        imx6ull)  
            imx6ull_build_img enable         
            ;;

        stm32mp157)
            stm32mp157_build_img enable
            ;;

        rk3328)
            rk3328_build_img enable
            ;;  
    esac

else
    echo "只默认更新根文件系统"
    #imx6ull_build_img
    #stm32mp157_build_img
    imx8mmini_build_img
    #rk3328_build_img
fi

# copy and rm file
end_time=`date +%s`
time_cal $(($end_time - $start_time))

#cp -ur ${IMAGE_BUILDER_DIR}/history/*  ${TARGET_DIR}/

rm -rf ${IMAGE_BUILDER_DIR}/deploy/
rm -rf ${IMAGE_BUILDER_DIR}/ignore/
rm -rf ${IMAGE_BUILDER_DIR}/history/imx6ull/
rm -rf ${IMAGE_BUILDER_DIR}/history/stm32mp157/
rm -rf ${IMAGE_BUILDER_DIR}/history/rockchip-3328/
#rm -rf ${IMAGE_BUILDER_DIR}/history/imx8m-mini/

