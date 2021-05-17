#!/bin/bash

IMAGE_BUILDER_BRANCH="$1"       #当前分支
CI_CONFIG="$2"                  #板级配置文件信息


#拉取image-builder更新
sleep 20     
git fetch --all
git reset --hard $IMAGE_BUILDER_BRANCH
git pull



#编译镜像
source ./env/$CI_CONFIG
echo "" | make  DOWNLOAD_MIRROR=china 







