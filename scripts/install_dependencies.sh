#!/bin/bash -e
#
# Copyright (c) 2012-2018 Robert Nelson <robertcnelson@gmail.com>
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

#http://ftp.us.debian.org/debian/pool/main/d/debootstrap/
#1.0.${minimal_debootstrap}
minimal_debootstrap="115"
host_arch="$(uname -m)"

debootstrap_is_installed () {
	unset deb_pkgs
	dpkg -l | grep debootstrap >/dev/null || deb_pkgs="${deb_pkgs}debootstrap "

	if [ "x${host_arch}" != "xarmv7l" ] ; then
		if [ "x${host_arch}" != "xaarch64" ] ; then
			#FIXME:...
			#echo "QEMU is un-reliable, thus no longer supported... Spend some Money and buy a real ARMHF device to run this script."
			#FIXME: comment out the next line to use QEMU
			#exit 2
			dpkg -l | grep qemu-user-static >/dev/null || deb_pkgs="${deb_pkgs}qemu-user-static "
			dpkg -l | grep $(dpkg --print-architecture) | grep -v "qemu-" | grep qemu >/dev/null || deb_pkgs="${deb_pkgs}qemu "
			dpkg -l | grep git >/dev/null || deb_pkgs="${deb_pkgs}git "
			dpkg -l | grep dosfstools >/dev/null || deb_pkgs="${deb_pkgs}dosfstools "
			dpkg -l | grep kpartx >/dev/null || deb_pkgs="${deb_pkgs}kpartx "
			dpkg -l | grep wget >/dev/null || deb_pkgs="${deb_pkgs}wget "
			dpkg -l | grep parted >/dev/null || deb_pkgs="${deb_pkgs}parted "
			dpkg -l | grep m4 >/dev/null || deb_pkgs="${deb_pkgs}m4 "
		fi
	fi



	if [ "${deb_pkgs}" ] ; then
		echo "Installing: ${deb_pkgs}"
		sudo apt-get update
		sudo apt-get -y install ${deb_pkgs}
	fi
}

debootstrap_what_version () {
	test_debootstrap=$(/usr/sbin/debootstrap --version | cut -f3 -d. | grep -o '^[0-9.]\+')
	echo "Log: debootstrap version: 1.0.$test_debootstrap"
}

debootstrap_is_installed
debootstrap_what_version

#if [[ "$test_debootstrap" < "$minimal_debootstrap" ]] ; then
#if [ "$test_debootstrap" -lt "$minimal_debootstrap" ] ; then
if [ ! "x$test_debootstrap" = "x$minimal_debootstrap" ] ; then
	echo "Log: Installing minimal debootstrap version: 1.0.${minimal_debootstrap}..."
	wget https://rcn-ee.com/mirror/debootstrap/debootstrap_1.0.${minimal_debootstrap}_all.deb
	sudo dpkg -i debootstrap_1.0.${minimal_debootstrap}_all.deb
	rm -rf debootstrap_1.0.${minimal_debootstrap}_all.deb || true
fi

