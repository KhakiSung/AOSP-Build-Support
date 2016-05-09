#!/bin/bash
# Program: 
#	Build Support
# 	Build code and binary compare libs and push to device
# Author: 
#	Khaki

function usage () {
	echo -e "Build Support version 1.0.4\n\n\
Build code and binary compare libs and push to device\n\
Options:\n\
    BUILD_COMMAND           - mm, mma, mmm PATH, mmma PATH\n\
    -jN                     - make job num. default -j4\n\
    -a, --autopush          - Auto push diff libs without asking user \n\
    -s, --snapshot          - Use current libs in dir PRODUCT_OUT/system as snapshot for compare standard\n\
    -l, --lib=SNAPSHOT_DIR  - Where compare libs standard put, default is PRODUCT_OUT/backup\n\
                              Support relative/absolute path. Root dir is PRODUCT_OUT/\n\
    -v, --verbose           - more log to stdout\n"
}

function push_lib () {
	if [ -z "$1" ]; then
		echo "Error! push an empty lib"
		return
	fi

	#Substring Removal: 
	#${string%substring} 
	#Deletes shortest match of $substring from back of $string.	
	local lib=$1
	local target=${lib%/*}
	echo -n "Flush $lib:"$'\t\t'

	#adb push $OUT$lib $target

	local output=$( { adb push $OUT$lib $target; } 2>&1 )

	local retry=0
	case $output in
		*"bytes in"*)
			echo $output
			;;
		*"No such file or directory"*)
			echo -e "\e[31m$output\e[0m"
			;;
		*"Read-only file system"*)
			echo -e "\e[31m$output\e[0m"
			echo -e "\e[32mTry remount devices, then push again. \e[0m"
			adb root
			adb wait-for-device
			adb remount
			adb push $OUT$lib $target

			# run retry loop if push still fail after remount
			if [ $? != 0 ]; then
				retry=1
			fi
			;;
		*)
			echo -e "\e[31m$output\e[0m"
			retry=1
			;;
	esac

	# loop of ask user to retry push lib
	if [ $retry != 0 ]; then
		while true; do
			read -p "Retry (Y/N)?" yn
			case $yn in
				[Yy]*)
					adb push $OUT$lib $target
					if [ $? == 0 ]; then
						break
					fi
					;;
				[Nn]*) break;;
			esac
		done
	fi	
}

# need execute by source because build command
if [[ "$0" == "$BASH_SOURCE" ]]; then
	echo "Please execute by source"
	exit
fi

# check croot exist
type croot >& /dev/null
if [ $? != 0 ]; then
	echo "code base didn't setup env!"
	return
fi

# check build command
if [ $# -eq 0 ]; then
	usage
	return
fi

flag_build_code=1
flag_need_snapshot=0
flag_auto_push=0
flag_verbose=0
SNAPSHOT_DIR="$OUT/backup/"
cmd=""
cmd_ext=""
job_num="-j4"

# args parse
while [[ $# > 0 ]]
do
key="$1"
case $key in
	-j[0-9]*)
		job_num=$key
		;;
	-a|--autopush)
		flag_auto_push=1
		;;
	-s|--snapshot)
		flag_need_snapshot=1
		;;
	-v|--verbose)
		flag_verbose=1
		;;
	-l=*|--lib=*)
		SNAPSHOT_DIR="${key#*=}"
		;;
	mm|mma)
		cmd=$key
		;;
	mmm|mmma)
		cmd=$key
		cmd_ext="$2"
		shift
		;;
	*)
		# unknown option
		echo "$key ?"
		usage
		return
		;;
esac
shift
done

if [ -z "$cmd" ] ; then
	usage
	return
fi

if [ $flag_verbose -eq 1 ]; then
	echo -e "\e[37mParsing parameter success! auto_push:($flag_auto_push) snapshot:($flag_need_snapshot) verbose:($flag_verbose) job_num:($job_num) cmd:($cmd) cmd_ext:($cmd_ext)\e[0m" 
fi

echo "Execute $cmd $cmd_ext $job_num"
build_cmd="$cmd $cmd_ext $job_num"
function main () {
	local current_path=$(pwd)

	# snapshot(backup) so file for binary compare
	if [ $flag_need_snapshot -eq 1 ]; then
		local print_file_cmd="echo -en \r\e[0K{}"
		if [ $flag_verbose -eq 1 ]; then 
			print_file_cmd="echo -e \e[37m{} \e[0m"
		fi
		echo -e "\e[32mCopy .so file to [ $SNAPSHOT_DIR ] started.\e[0m"
		cd "$OUT"
		test -d "$SNAPSHOT_DIR" || mkdir -p "$SNAPSHOT_DIR"
		echo "Copying........ [ system/lib/ ]"
		find system/lib -name "*.so" 		-type f -exec $print_file_cmd \; -exec cp --parents {} $SNAPSHOT_DIR \;
		echo -e "\r\e[0KCopying........ [ system/lib/hw ]"
		find system/lib/hw -name "*.so" 	-type f -exec $print_file_cmd \; -exec cp --parents {} $SNAPSHOT_DIR \;
		echo -e "\r\e[0KCopying........ [ system/vendor/lib/ ]"
		find system/vendor/lib -name "*.so" -type f -exec $print_file_cmd \; -exec cp --parents {} $SNAPSHOT_DIR \;
		echo -e "\r\e[0KCopying........ [ system/bin/ ]"
		find system/bin/			 		-type f -exec $print_file_cmd \; -exec cp --parents {} $SNAPSHOT_DIR \;
		cd "$current_path"
		echo -e "\r\e[0K\e[32mCopy finished.\e[0m"
	fi

	local install_list=()
	local compare_result=()
	local select_box_input=()

	if [ $flag_verbose -eq 1 ]; then
		echo -e "\e[37m Start build code command: $cmd $cmd_ext\e[0m"
	fi

	# build code
	if [ $flag_build_code -eq 1 ]; then
		local build_success=0
		while read -r line; do
			if [[ $line == Install* ]]; then
				echo -e "\e[32m$line \e[0m"
				if [[ $line == */system/* ]]; then
					install_list+=("/system/${line#*/system/}")
				fi
			elif [[ $line == *"make completed successfully"* ]]; then
				build_success=1
				echo $line
			else
				echo $line
			fi		
		done < <($build_cmd)
		if [ $build_success -eq 0 ]; then
			return
		fi
	fi

	if [ $flag_verbose -eq 1 ]; then
		echo -e "\e[37mDump install parsed\e[0m"
		for ((i = 0; i < ${#install_list[@]}; i++)) ; do
			echo -e "\e[37m${install_list[$i]}\e[0m"
		done
		echo -e "\e[37mDump end\e[0m"
	fi

	# binary compare
	echo -e "\e[32mStart binary compare...\e[0m"
	cd "$OUT"
	for ((i = 0; i < ${#install_list[@]}; i++))
	do
		local path="${install_list[$i]}"
		cmp -b "$OUT$path" "$SNAPSHOT_DIR$path" > /dev/null
		local result=$?
		local need_push=0
		local select_box_input_string="FALSE $path $i"
		if [ $result != 0 ]; then
			echo -e "Diff: \e[32m$path\e[0m"
			if [[ $path != *test* ]]; then
				select_box_input_string="TRUE $path $i"
				need_push=1
			fi
		fi
		select_box_input+=("$select_box_input_string")
		compare_result+=("$need_push")
	done
	cd "$current_path"
	echo -e "\e[32mBinary campare end.\e[0m"

	if [ $flag_verbose -eq 1 ]; then
		echo -e "\e[37mDump select_box_input\e[0m"
		for ((i = 0; i < ${#select_box_input[@]}; i++)) ; do
			echo -e "\e[37m${select_box_input[$i]}\e[0m"
		done
		echo -e "\e[37mDump end\e[0m"
	fi

	if [ -z "$select_box_input" ] ; then
		echo -e "\e[31mNo thing need to push.\e[0m"
		return
	fi

	# push lib
	if [ $flag_auto_push -eq 0 ]; then
		# launch UI to select libs
		choice=$(zenity --width=600 --height=400 --title="Please select libs to push" --text="libs which binary different to snapshot selected by default." --list --checklist --column="needs" --column=libs --column=Index --print-column=3 --hide-column=3 --separator=' ' ${select_box_input[@]})
		if [ -z "$choice" ] ; then
		   echo "No selection"
		   return
		fi

		if [ $flag_verbose -eq 1 ]; then
			echo -e "\e[37mDump user choice libs\e[0m"
			for i in $choice ; do
				echo -e "\e[37m${install_list[$i]}\e[0m"
			done
			echo -e "\e[37mDump end\e[0m"
		fi

		for i in $choice ; do 
			push_lib ${install_list[$i]}
		done
	else
		for ((i = 0; i < ${#install_list[@]}; i++))
		do
			if [[ ${compare_result[$i]} -eq 1 ]]; then
				push_lib ${install_list[$i]}
			fi
		done
	fi
}
main