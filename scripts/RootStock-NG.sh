#!/bin/bash -e
#
# Copyright (c) 2013 Robert Nelson <robertcnelson@gmail.com>
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
[ -n "$BUILD_DEBUG" ] && set -x

system=$(uname -n)
HOST_ARCH=$(uname -m)
TIME=$(date +%Y-%m-%d)

DIR="$PWD"

usage () {
	echo "usage: ./RootStock-NG.sh -c XXX"
}

checkparm () {
	if [ "$(echo $1|grep ^'\-')" ] ; then
		echo "E: Need an argument"
		usage
	fi
}

check_project_config () {

	if [ ! -d ${DIR}/ignore ] ; then
		mkdir -p ${DIR}/ignore
	fi
	tempdir=$(mktemp -d -p ${DIR}/ignore)

	time=$(date +%Y-%m-%d)

	#/configs/boards/${project_config}.conf
	unset leading_slash
	leading_slash=$(echo ${project_config} | grep "/" || unset leading_slash)
	if [ "${leading_slash}" ] ; then
		project_config=$(echo "${leading_slash##*/}")
	fi

	#${project_config}.conf
	project_config=$(echo ${project_config} | awk -F ".conf" '{print $1}')
	if [ -f ${DIR}/configs/boards/${project_config}.conf ] ; then
		. <(m4 -P ${DIR}/configs/boards/${project_config}.conf)
		export_filename="${deb_distribution}-${release}-${DISTRIB_TYPE}-${deb_arch}-${time}"

		# for automation
		echo "${export_filename}" > ${DIR}/latest_version

		echo "tempdir=\"${tempdir}\"" > ${DIR}/.project
		echo "time=\"${time}\"" >> ${DIR}/.project
		echo "export_filename=\"${export_filename}\"" >> ${DIR}/.project
		echo "#" >> ${DIR}/.project
		m4 -P ${DIR}/configs/common.conf >> ${DIR}/.project
		echo "" >> ${DIR}/.project
		m4 -P ${DIR}/configs/user.conf >> ${DIR}/.project
		echo "" >> ${DIR}/.project
		m4 -P ${DIR}/configs/boards/${project_config}.conf >> ${DIR}/.project
	else
		echo "Invalid *.conf"
		exit
	fi
}

check_saved_config () {

	if [ ! -d ${DIR}/ignore ] ; then
		mkdir -p ${DIR}/ignore
	fi
	tempdir=$(mktemp -d -p ${DIR}/ignore)

	if [ ! -f ${DIR}/.project ] ; then
		echo "Couldn't find .project"
		exit
	fi
}

if [ -f ${DIR}/.project ] ; then
	. ${DIR}/.project
fi

unset need_to_compress_rootfs
# parse commandline options
while [ ! -z "$1" ] ; do
	case $1 in
	-h|--help)
		usage
		exit
		;;
	-c|-C|--config)
		checkparm $2
		project_config="$2"
		check_project_config
		;;
	--saved-config)
		check_saved_config
		;;
	esac
	shift
done

mkdir -p ${DIR}/ignore

generic_git () {
	if [ ! -f ${DIR}/git/${git_project_name}/.git/config ] ; then
		git clone ${git_clone_address} ${DIR}/git/${git_project_name} --depth=1
	fi
}

update_git () {
	if [ -f ${DIR}/git/${git_project_name}/.git/config ] ; then
		cd ${DIR}/git/${git_project_name}/
		git pull --rebase || true
		cd -
	fi
}

git_trees () {
	if [ ! -d ${DIR}/git/ ] ; then
		mkdir -p ${DIR}/git/
	fi

	git_project_name="linux-firmware"
	git_clone_address="https://gitee.com/Embedfire/linux-firmware.git"
	generic_git
	update_git
}

run_roostock_ng () {
	if [ ! -f ${DIR}/.project ] ; then
		echo "error: [.project] file not defined"
		exit 1
	else
		echo "Debug: .project"
		echo "-----------------------------"
		cat ${DIR}/.project
		echo "-----------------------------"
	fi

	if [ ! "${tempdir}" ] ; then
		tempdir=$(mktemp -d -p ${DIR}/ignore)
		echo "tempdir=\"${tempdir}\"" >> ${DIR}/.project
	fi

	/bin/bash -e "${BUILD_SCRIPT}/install_dependencies.sh" || { exit 1 ; }

	if [ -f "${DIR}/history/tempdir/$(date +%Y-%m)/${DISTRIBUTION}/${DISTRIB_RELEASE}/${ARCH}/basefs.tar" ] ;then
		cd $tempdir
		sudo tar -xvf "${DIR}/history/tempdir/$(date +%Y-%m)/${DISTRIBUTION}/${DISTRIB_RELEASE}/${ARCH}/basefs.tar"
		cd $DIR 
	else
		/bin/bash -e "${BUILD_SCRIPT}/debootstrap.sh" || { exit 1 ; }	#创建基本根文件系统
	fi
	
	/bin/bash -e "${BUILD_SCRIPT}/chroot.sh" || { exit $? ; }
	#sudo rm -rf ${tempdir}/ || true
}

git_trees

cd ${DIR}/

run_roostock_ng

#
