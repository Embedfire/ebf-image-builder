#!/bin/bash

set -e -o pipefail

## Parameters
source configs/common.conf

## Board configuraions
source ${BOARD_CONFIG}/${FIRE_BOARD}.conf

## Functions
source configs/functions/functions

######################################################################################
TARGET="$1"

case "$TARGET" in
	u-boot)
		build_uboot
		;;
	linux)
		build_linux $2
		;;
	linux-deb)
		build_linux_debs
		;;
esac

echo -e "\nDone."
echo -e "\n`date`"
