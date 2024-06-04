#!/bin/bash

################################################################
ROOT="$(pwd)"
unset SUPPORTED_TFA
unset SUPPORTED_UBOOT
unset SUPPORTED_UBOOT_TAGS
unset SUPPORTED_LINUX
unset SUPPORTED_LINUX_TAGS

DISTRIBUTION_ARRAY=("Debian" "Ubuntu")
Ubuntu_RELEASE_ARRAY=("bionic" "focal")
Debian_RELEASE_ARRAY=("buster" "bullseye")
Ubuntu_TYPE_ARRAY=("console" "qt" "xfce")
Debian_TYPE_ARRAY=("tiny" "console" "qt" "xfce")
INSTALL_TYPE_ARRAY=("ALL" "NAND" "eMMC/SD")

DISTRIBUTION_ARRAY_LEN=${#DISTRIBUTION_ARRAY[@]}
Ubuntu_RELEASE_ARRAY_LEN=${#Ubuntu_RELEASE_ARRAY[@]}
Debian_RELEASE_ARRAY_LEN=${#Debian_RELEASE_ARRAY[@]}
Ubuntu_TYPE_ARRAY_LEN=${#Ubuntu_TYPE_ARRAY[@]}
Debian_TYPE_ARRAY_LEN=${#Debian_TYPE_ARRAY[@]}
INSTALL_TYPE_ARRAY_LEN=${#INSTALL_TYPE_ARRAY[@]}

FIRE_BOARD=
LINUX=
UBOOT=
DISTRIBUTION=
DISTRIB_RELEASE=
INSTALL_TYPE=
DISTRIB_TYPE=
VENDOR=
CHIP=

LOAD_CONFIG_FROM_FILE=
CONFIG_FILE=
###############################################################
## Hangup
function hangup() {
	while true; do
		sleep 10
	done
}

if [ "$1" == "config" ]; then
	if [ ! -f "$2" ]; then
		echo -e "Configuration file: \e[1;32m$2\e[0m doesn't exist!"
		echo -e "\e[0;32mCtrl+C\e[0m to abort."
		hangup
	fi
	echo -e "Loading configuration from file: \e[1;32m$2\e[0m"
	LOAD_CONFIG_FROM_FILE="yes"
	CONFIG_FILE="$2"
fi

## check directory
function check_directory() {
	if [ ! -d "$ROOT/env" ]; then
		echo -e "\e[31mError:\e[0m You should execute the script in ebf-image-builder root directory by executing \e[0;32msource env/setenv.sh\e[0m.Please enter ebf-image-builder root directory and try again."
		echo -e "\e[0;32mCtrl+C\e[0m to abort."
		# Hang
		hangup
	fi
}

## Choose fire board
function choose_fire_board() {
	echo ""
	echo "Choose fire board:"
	i=0

	FIRE_BOARD_ARRAY=()
	for board in $ROOT/configs/boards/*.conf; do
		FIRE_BOARD_ARRAY+=("$(basename $board | cut -d'.' -f1)")
	done

	FIRE_BOARD_ARRAY_LEN=${#FIRE_BOARD_ARRAY[@]}

	while [[ $i -lt $FIRE_BOARD_ARRAY_LEN ]]
	do
		echo "$((${i}+1)). ${FIRE_BOARD_ARRAY[$i]}"
		let i++
	done

	echo ""

	local DEFAULT_NUM
	DEFAULT_NUM=1

	export FIRE_BOARD=
	local ANSWER
	while [ -z $FIRE_BOARD ]
	do
		echo -n "Which board would you like? ["$DEFAULT_NUM"] "
		if [ -z "$1" ]; then
			read ANSWER
		else
			echo $1
			ANSWER=$1
		fi

		if [ -z "$ANSWER" ]; then
			ANSWER="$DEFAULT_NUM"
		fi

		if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
			if [ $ANSWER -le $FIRE_BOARD_ARRAY_LEN ] && [ $ANSWER -gt 0 ]; then
				index=$((${ANSWER}-1))
				FIRE_BOARD="${FIRE_BOARD_ARRAY[$index]}"
			else
				echo
				echo "number not in range. Please try again."
				echo
			fi
		else
			echo
			echo "I didn't understand your response.  Please try again."
			echo
		fi
		if [ -n "$1" ]; then
			break
		fi
	done

	source $ROOT/configs/boards/${FIRE_BOARD}.conf
}

## Choose tfa version
function choose_tfa_version() {
    TFA_VERSION_ARRAY_LEN=${#SUPPORTED_TFA[@]}

	if [ $TFA_VERSION_ARRAY_LEN == 0 ]; then
		echo "Skiping tfa... "
		return 0
	fi
    echo ""
    echo "Choose uboot version:"
    i=0
    while [[ $i -lt ${TFA_VERSION_ARRAY_LEN} ]]
    do
        echo "$((${i}+1)). tfa-${SUPPORTED_TFA[$i]}"
        let i++
    done

    echo ""

 	local DEFAULT_NUM
    DEFAULT_NUM=1
    export TFA=
    local ANSWER
    while [ -z $TFA ]
    do
        echo -n "Which tfa version would you like? ["$DEFAULT_NUM"] "
        if [ -z "$1" ]; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi

        if [ -z "$ANSWER" ]; then
            ANSWER="$DEFAULT_NUM"
        fi

        if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
            if [ $ANSWER -le ${TFA_VERSION_ARRAY_LEN} ] && [ $ANSWER -gt 0 ]; then
                index=$((${ANSWER}-1))
                TFA="${SUPPORTED_TFA[$index]}"
            else
                echo
                echo "number not in range. Please try again."
                echo
            fi
        else
            echo
            echo "I didn't understand your response.  Please try again."

            echo
        fi
        if [ -n "$1" ]; then
            break
        fi
    done
}

## Choose uboot version
function choose_uboot_version() {
    echo ""
    echo "Choose uboot version:"
    i=0

    UBOOT_VERSION_ARRAY_LEN=${#SUPPORTED_UBOOT[@]}

	if [ $UBOOT_VERSION_ARRAY_LEN == 0 ]; then
		echo -e "\033[31mError:\033[0m Missing 'SUPPORTED_UBOOT' in board configuration file '$ROOT/configs/boards/${FIRE_BOARD}.conf'? Please add it!"
		echo -e "Hangup here! \e[0;32mCtrl+C\e[0m to abort."
		hangup
	fi

    while [[ $i -lt ${UBOOT_VERSION_ARRAY_LEN} ]]
    do
        echo "$((${i}+1)). uboot-${SUPPORTED_UBOOT[$i]}"
        let i++
    done

    echo ""

    local DEFAULT_NUM
    DEFAULT_NUM=1
    export UBOOT=
    local ANSWER
    while [ -z $UBOOT ]
    do
        echo -n "Which uboot version would you like? ["$DEFAULT_NUM"] "
        if [ -z "$1" ]; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi

        if [ -z "$ANSWER" ]; then
            ANSWER="$DEFAULT_NUM"
        fi

        if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
            if [ $ANSWER -le ${UBOOT_VERSION_ARRAY_LEN} ] && [ $ANSWER -gt 0 ]; then
                index=$((${ANSWER}-1))
                UBOOT="${SUPPORTED_UBOOT[$index]}"
            else
                echo
                echo "number not in range. Please try again."
                echo
            fi
        else
            echo
            echo "I didn't understand your response.  Please try again."

            echo
        fi
        if [ -n "$1" ]; then
            break
        fi
    done
}

function choose_uboot_tag() {
    echo ""
    echo "Choose uboot tag:"
    i=0

    UBOOT_TAGS_ARRAY_LEN=${#SUPPORTED_UBOOT_TAGS[@]}

	if [ $UBOOT_TAGS_ARRAY_LEN == 0 ]; then
		echo -e "\033[31mError:\033[0m Missing 'SUPPORTED_UBOOT_TAGS' in board configuration file '$ROOT/configs/boards/${FIRE_BOARD}.conf'? Please add it!"
		echo -e "Hangup here! \e[0;32mCtrl+C\e[0m to abort."
		hangup
	fi

    while [[ $i -lt ${UBOOT_TAGS_ARRAY_LEN} ]]
    do
        echo "$((${i}+1)). uboot-${SUPPORTED_UBOOT_TAGS[$i]}"
        let i++
    done

    echo ""

    local DEFAULT_NUM
    DEFAULT_NUM=1
    export UBOOT_TAGS=
    local ANSWER
    while [ -z $UBOOT_TAGS ]
    do
        echo -n "Which uboot tag would you like? ["$DEFAULT_NUM"] "
        if [ -z "$1" ]; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi

        if [ -z "$ANSWER" ]; then
            ANSWER="$DEFAULT_NUM"
        fi

        if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
            if [ $ANSWER -le ${UBOOT_TAGS_ARRAY_LEN} ] && [ $ANSWER -gt 0 ]; then
                index=$((${ANSWER}-1))
                UBOOT_TAGS="${SUPPORTED_UBOOT_TAGS[$index]}"
            else
                echo
                echo "number not in range. Please try again."
                echo
            fi
        else
            echo
            echo "I didn't understand your response.  Please try again."

            echo
        fi
        if [ -n "$1" ]; then
            break
        fi
    done
}

## Choose linux version
function choose_linux_version() {
	echo ""
	echo "Choose linux version:"
	# FIXME
	if [ "$UBOOT" == "mainline" ]; then
		SUPPORTED_LINUX=("mainline")
	else
		SUPPORTED_LINUX=(`echo ${SUPPORTED_LINUX[@]} | sed s/mainline//g`)
	fi

	i=0

	LINUX_VERSION_ARRAY_LEN=${#SUPPORTED_LINUX[@]}
	if [ $LINUX_VERSION_ARRAY_LEN == 0 ]; then
		echo -e "\033[31mError:\033[0m Missing 'SUPPORTED_LINUX' in board configuration file '$ROOT/configs/boards/${FIRE_BOARD}.conf'? Please add it!"
		echo -e "Hangup here! \e[0;32mCtrl+C\e[0m to abort."
		hangup
	fi

	while [[ $i -lt ${LINUX_VERSION_ARRAY_LEN} ]]
	do
		echo "$((${i}+1)). linux-${SUPPORTED_LINUX[$i]}"
		let i++
	done

	echo ""

	local DEFAULT_NUM
	DEFAULT_NUM=1

	export LINUX=
	local ANSWER
	while [ -z $LINUX ]
	do
		echo -n "Which linux version would you like? ["$DEFAULT_NUM"] "
		if [ -z "$1" ]; then
			read ANSWER
		else
			echo $1
			ANSWER=$1
		fi

		if [ -z "$ANSWER" ]; then
			ANSWER="$DEFAULT_NUM"
		fi

		if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
			if [ $ANSWER -le ${LINUX_VERSION_ARRAY_LEN} ] && [ $ANSWER -gt 0 ]; then
				index=$((${ANSWER}-1))
				LINUX="${SUPPORTED_LINUX[$index]}"
			else
				echo
				echo "number not in range. Please try again."
				echo
			fi
		else
			echo
			echo "I didn't understand your response.  Please try again."

			echo
		fi
		if [ -n "$1" ]; then
			break
		fi
	done
}

function choose_linux_tag() {
	echo ""
	echo "Choose linux tag:"
	i=0

	LINUX_TAGS_ARRAY_LEN=${#SUPPORTED_LINUX_TAGS[@]}
	if [ $LINUX_TAGS_ARRAY_LEN == 0 ]; then
		echo -e "\033[31mError:\033[0m Missing 'SUPPORTED_LINUX_TAGS' in board configuration file '$ROOT/configs/boards/${FIRE_BOARD}.conf'? Please add it!"
		echo -e "Hangup here! \e[0;32mCtrl+C\e[0m to abort."
		hangup
	fi

	while [[ $i -lt ${LINUX_TAGS_ARRAY_LEN} ]]
	do
		echo "$((${i}+1)). linux-${SUPPORTED_LINUX_TAGS[$i]}"
		let i++
	done

	echo ""

	local DEFAULT_NUM
	DEFAULT_NUM=1

	export LINUX_TAGS=
	local ANSWER
	while [ -z $LINUX_TAGS ]
	do
		echo -n "Which linux tag would you like? ["$DEFAULT_NUM"] "
		if [ -z "$1" ]; then
			read ANSWER
		else
			echo $1
			ANSWER=$1
		fi

		if [ -z "$ANSWER" ]; then
			ANSWER="$DEFAULT_NUM"
		fi

		if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
			if [ $ANSWER -le ${LINUX_TAGS_ARRAY_LEN} ] && [ $ANSWER -gt 0 ]; then
				index=$((${ANSWER}-1))
				LINUX_TAGS="${SUPPORTED_LINUX_TAGS[$index]}"
			else
				echo
				echo "number not in range. Please try again."
				echo
			fi
		else
			echo
			echo "I didn't understand your response.  Please try again."

			echo
		fi
		if [ -n "$1" ]; then
			break
		fi
	done
}

## Choose distribution
function choose_distribution() {
	echo ""
	echo "Choose distribution:"
	i=0
	while [[ $i -lt $DISTRIBUTION_ARRAY_LEN ]]
	do
		echo "$((${i}+1)). ${DISTRIBUTION_ARRAY[$i]}"
		let i++
	done

	echo ""

	local DEFAULT_NUM
	DEFAULT_NUM=1

	export DISTRIBUTION
	local ANSWER
	while [ -z $DISTRIBUTION ]
	do
		echo -n "Which distribution would you like? ["$DEFAULT_NUM"] "
		if [ -z "$1" ]; then
			read ANSWER
		else
			echo $1
			ANSWER=$1
		fi

		if [ -z "$ANSWER" ]; then
			ANSWER="$DEFAULT_NUM"
		fi

		if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
			if [ $ANSWER -le $DISTRIBUTION_ARRAY_LEN ] && [ $ANSWER -gt 0 ]; then
				index=$((${ANSWER}-1))
				DISTRIBUTION="${DISTRIBUTION_ARRAY[$index]}"
			else
				echo
				echo "number not in range. Please try again."
				echo
			fi
		else
			echo
			echo "I didn't understand your response.  Please try again."
			echo
		fi
		if [ -n "$1" ]; then
			break
		fi
	done
}

## Choose distribution release
function choose_distribution_release() {
	echo ""
	echo "Choose ${DISTRIBUTION} release:"

	i=0
	local DISTRIBUTION_RELEASE_ARRAY_LEN
	local DISTRIBUTION_RELEASE_ELEMENT
	local DISTRIBUTION_RELEASE

	DISTRIBUTION_RELEASE_ARRAY_LEN=${DISTRIBUTION}_RELEASE_ARRAY_LEN
	while [[ $i -lt ${!DISTRIBUTION_RELEASE_ARRAY_LEN} ]]
	do
		DISTRIBUTION_RELEASE_ARRAY_ELEMENT=${DISTRIBUTION}_RELEASE_ARRAY[$i]
		DISTRIBUTION_RELEASE=${!DISTRIBUTION_RELEASE_ARRAY_ELEMENT}
		echo "$((${i}+1)). ${DISTRIBUTION_RELEASE}"
		let i++
	done

	echo ""

	local DEFAULT_NUM
	DEFAULT_NUM=1

	export DISTRIB_RELEASE=
	local ANSWER
	while [ -z $DISTRIB_RELEASE ]
	do
		echo -n "Which ${DISTRIBUTION} release would you like? ["$DEFAULT_NUM"] "
		if [ -z "$1" ]; then
			read ANSWER
		else
			echo $1
			ANSWER=$1
		fi

		if [ -z "$ANSWER" ]; then
			ANSWER="$DEFAULT_NUM"
		fi

		if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
			if [ $ANSWER -le ${!DISTRIBUTION_RELEASE_ARRAY_LEN} ] && [ $ANSWER -gt 0 ]; then
				index=$((${ANSWER}-1))
				DISTRIBUTION_RELEASE_ARRAY_ELEMENT=${DISTRIBUTION}_RELEASE_ARRAY[$index]
				DISTRIB_RELEASE="${!DISTRIBUTION_RELEASE_ARRAY_ELEMENT}"
			else
				echo
				echo "number not in range. Please try again."
				echo
			fi
		else
			echo
			echo "I didn't understand your response.  Please try again."

			echo
		fi
		if [ -n "$1" ]; then
			break
		fi
	done
}

## Choose distribution type
function choose_distribution_type() {
	echo ""
	echo "Choose ${DISTRIBUTION} type:"

	i=0
	local DISTRIBUTION_TYPE_ARRAY_LEN
	local DISTRIBUTION_TYPE_ELEMENT
	local DISTRIBUTION_TYPE

	DISTRIBUTION_TYPE_ARRAY_LEN=${DISTRIBUTION}_TYPE_ARRAY_LEN
	while [[ $i -lt ${!DISTRIBUTION_TYPE_ARRAY_LEN} ]]
	do
		DISTRIBUTION_TYPE_ARRAY_ELEMENT=${DISTRIBUTION}_TYPE_ARRAY[$i]
		DISTRIBUTION_TYPE=${!DISTRIBUTION_TYPE_ARRAY_ELEMENT}
		echo "$((${i}+1)). ${DISTRIBUTION_TYPE}"
		let i++
	done

	echo ""

	local DEFAULT_NUM
	DEFAULT_NUM=1

	export DISTRIB_TYPE=
	local ANSWER
	while [ -z $DISTRIB_TYPE ]
	do
		echo -n "Which ${DISTRIBUTION} type would you like? ["$DEFAULT_NUM"] "
		if [ -z "$1" ]; then
			read ANSWER
		else
			echo $1
			ANSWER=$1
		fi

		if [ -z "$ANSWER" ]; then
			ANSWER="$DEFAULT_NUM"
		fi

		if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
			if [ $ANSWER -le ${!DISTRIBUTION_TYPE_ARRAY_LEN} ] && [ $ANSWER -gt 0 ]; then
				index=$((${ANSWER}-1))
				DISTRIBUTION_TYPE_ARRAY_ELEMENT=${DISTRIBUTION}_TYPE_ARRAY[$index]
				DISTRIB_TYPE="${!DISTRIBUTION_TYPE_ARRAY_ELEMENT}"
			else
				echo
				echo "number not in range. Please try again."
				echo
			fi
		else
			echo
			echo "I didn't understand your response.  Please try again."

			echo
		fi
		if [ -n "$1" ]; then
			break
		fi
	done
}

function choose_install_type() {
	echo ""
	echo "Choose install type:"
	i=0
	while [[ $i -lt $INSTALL_TYPE_ARRAY_LEN ]]
	do
		echo "$((${i}+1)). ${INSTALL_TYPE_ARRAY[$i]}"
		let i++
	done

	echo ""

	local DEFAULT_NUM
	DEFAULT_NUM=3

	export INSTALL_TYPE=
	local ANSWER
	while [ -z $INSTALL_TYPE ]
	do
		echo -n "Which install type would you like? ["$DEFAULT_NUM"] "
		if [ -z "$1" ]; then
			read ANSWER
		else
			echo $1
			ANSWER=$1
		fi

		if [ -z "$ANSWER" ]; then
			ANSWER="$DEFAULT_NUM"
		fi

		if [ -n "`echo $ANSWER | sed -n '/^[0-9][0-9]*$/p'`" ]; then
			if [ $ANSWER -le $INSTALL_TYPE_ARRAY_LEN ] && [ $ANSWER -gt 0 ]; then
				index=$((${ANSWER}-1))
				INSTALL_TYPE="${INSTALL_TYPE_ARRAY[$index]}"
			else
				echo
				echo "number not in range. Please try again."
				echo
			fi
		else
			echo
			echo "I didn't understand your response.  Please try again."
			echo
		fi

		if [ -n "$1" ]; then
			break
		fi
	done
}

function lunch() {
	echo "==========================================="
	echo
	echo "#FIRE_BOARD=${FIRE_BOARD}"
	echo "#TFA=${TFA}"
	echo "#LINUX=${LINUX}"
	echo "#UBOOT=${UBOOT}"
	echo "#DISTRIBUTION=${DISTRIBUTION}"
	echo "#DISTRIB_RELEASE=${DISTRIB_RELEASE}"
	echo "#DISTRIB_TYPE=${DISTRIB_TYPE}"
	echo "#INSTALL_TYPE=${INSTALL_TYPE}"
	echo
	echo "==========================================="
	echo ""
	echo "Environment setup done."
	echo "Type 'make' or 'make DOWNLOAD_MIRROR=china' to build."
	echo ""
}

function load_config_from_file() {
	source $CONFIG_FILE
	export FIRE_BOARD
	export LINUX
	export UBOOT
	export DISTRIBUTION
	export DISTRIB_RELEASE
	export DISTRIB_TYPE
	export INSTALL_TYPE
}

#####################################################################3
check_directory
if [ -z "$LOAD_CONFIG_FROM_FILE" ]; then
    choose_install_type
	choose_fire_board
	choose_tfa_version
	choose_uboot_version
	choose_uboot_tag
	choose_linux_version
	choose_linux_tag
	choose_distribution
	choose_distribution_release
	choose_distribution_type
else
	load_config_from_file
fi
lunch

LINUX_DIR=${LINUX_DIR}
export LINUX_DIR
