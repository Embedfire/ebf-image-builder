#!/bin/bash


CI_CONFIG="$1"

#拉取image-builder更新
sleep 20     
git fetch --all
git reset --hard CI/CD_test
git pull



#编译镜像
source ./env/$CI_CONFIG
echo "" | make  DOWNLOAD_MIRROR=china 







