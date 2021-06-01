#!/bin/bash

set -e -o pipefail


IMAGE_BUILDER_DIR=/opt/ebf-image-builder
TARGET_DIR=/mnt/share

GIT_CLONE_OPTIONS="--depth=1"
IMAGE_BUILDER_GIT_TAGS=image-builder_2.0
IMAGE_BUILDER_SOURCE_URL="git@gitlab.embedfire.local:i.mx6/ebf-image-builder.git"


source configs/functions/functions


start_time=`date +%s`

if [ ! -d ${IMAGE_BUILDER_DIR}/.git ]; then
    info_msg "Image-builder  repository does not exist, clone image-builder repository('$1') from '$IMAGE_BUILDER_SOURCE_URL'..."
    ## Clone u-boot from Khadas GitHub
    if [ "$1" == "" ]; then
        git clone $GIT_CLONE_OPTIONS $IMAGE_BUILDER_SOURCE_URL -b $IMAGE_BUILDER_GIT_TAGS $IMAGE_BUILDER_DIR
        [ $? != 0 ] && error_msg "Failed to clone 'image-builder'" && return -1
    else
        git clone $GIT_CLONE_OPTIONS $IMAGE_BUILDER_SOURCE_URL -b $1 $IMAGE_BUILDER_DIR
        [ $? != 0 ] && error_msg "Failed to clone 'image-builder'" && return -1
    fi
fi

cd $IMAGE_BUILDER_DIR

#拉取image-builder更新
sleep 20     
git fetch --all

if [ "$1" == "" ]; then
    git reset --hard $IMAGE_BUILDER_GIT_TAGS
else
    git reset --hard $1
fi

git pull


#编译镜像 debian console
export FIRE_BOARD=ebf_imx_6ull_pro
export LINUX=4.19.35
export UBOOT=2020.10
export DISTRIBUTION=Debian
export DISTRIB_RELEASE=buster
export DISTRIB_TYPE=console
export INSTALL_TYPE=ALL

make  DOWNLOAD_MIRROR=china 

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


#cope to target_dir

cp -rn ${IMAGE_BUILDER_DIR}/history  ${TARGET_DIR}/

end_time=`date +%s`
time_cal $(($end_time - $start_time))

