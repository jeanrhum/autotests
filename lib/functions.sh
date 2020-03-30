#!/bin/bash
#
# mask_ip
#
#




#
# Masking IP prefix address to make report copy/paste ready
#

function mask_ip(){

	echo $1 | cut -d . -f 3,4

}




#
# Remote execution wrapper
#
function remote_exec(){

	f=0;
	while ! nc -zvw3 $USER_HOST 22 &>/dev/null
	do
		sleep 1; f=$(( $f + 1 )); [[ $f -gt 5 ]] && return 1
	done
	[[ $? -eq 0 ]] && sshpass -p ${PASS_ROOT} ssh ${2} ${USER_ROOT}@${USER_HOST} "${1}" 2> /dev/null

}



#
# Get board data
#
function get_board_data(){

	BOARD_DATA=$(remote_exec "cat /etc/armbian-release")
	BOARD_KERNEL=$(remote_exec "uname -sr")
	echo -e "$BOARD_DATA" >> ${SRC}/logs/${USER_HOST}.txt 2>&1
	BOARD_NAME=$(echo -e "$BOARD_DATA" | grep BOARD_NAME | sed 's/\"//g' | cut -d "=" -f2)
	BOARD_URL="https://www.armbian.com/"$(echo -e "$BOARD_DATA" | grep BOARD | head -1 | cut -d "=" -f2)
	BOARD_VERSION=$(echo -e "$BOARD_DATA" | grep VERSION | head -1 | cut -d "=" -f2)
	BOARD_DISTRIBUTION_CODENAME=$(echo -e "$BOARD_DATA" | grep DISTRIBUTION_CODENAME | head -1 | cut -d "=" -f2)
	BOARD_IMAGE_TYPE=$(echo -e "$BOARD_DATA" | grep IMAGE_TYPE | head -1 | cut -d "=" -f2)
	BOARD_LINUXFAMILY=$(echo -e "$BOARD_DATA" | grep LINUXFAMILY | head -1 | cut -d "=" -f2)
	BOARD_BRANCH=$(echo -e "$BOARD_DATA" | grep BRANCH | head -1 | cut -d "=" -f2)

}




#
# get_ip_addresses or interfaces
#
function get_device() {
	local ips=()
	remote_exec '
	for f in /sys/class/net/*; do
		intf=$(basename $f)
		# match only interface names starting with e (Ethernet), br (bridge) 
		# w (wireless), r (some Ralink drivers use ra<number> format)
		if [[ "$intf" =~ '$1' ]]; then
			tmp=$(ip -4 addr show dev $intf | grep inet | awk "{print \$2}" | cut -d"/" -f1)
			if [[ "'$2'" == ip ]]; then
				[[ -n $tmp ]] && echo $tmp
			elif [[ "'$2'" == noip ]]; then
				[[ -z "$tmp" && -n "$intf" ]] && echo $intf
			else
				echo $intf
			fi
		fi
	done'

}




#
# Let's have unique way of displaying alerts
#

display_alert()
{
	local tmp=""
	[[ -n $2 ]] && tmp="[\e[0;33m $2 \x1B[0m]"

	case $3 in
		err)
		echo -e "[\e[0;31m err. \x1B[0m] $1 $tmp" | tee -a ${SRC}/logs/${REPORT}-$(mask_ip "$USER_HOST").log
		;;

		wrn)
		echo -e "[\e[0;35m warn \x1B[0m] $1 $tmp" | tee -a ${SRC}/logs/${REPORT}-$(mask_ip "$USER_HOST").log
		;;

		ext)
		echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m$1\x1B[0m $tmp" | tee -a ${SRC}/logs/${REPORT}-$(mask_ip "$USER_HOST").log
		;;

		info)
		echo -e "[\e[0;32m o.k. \x1B[0m] $1 $tmp" | tee -a ${SRC}/logs/${REPORT}-$(mask_ip "$USER_HOST").log
		;;

		*)
		echo -e "[\e[0;32m .... \x1B[0m] $1 $tmp" | tee -a ${SRC}/logs/${REPORT}-$(mask_ip "$USER_HOST").log
		;;
	esac
}


function wait_for_board
{

		# wait for a board for a while
		i=1
		while ! ping -c1 $USER_HOST &>/dev/null; do 
			display_alert "Ping $USER_HOST failed $i" "$(date  +%R:%S)" "info"
			sleep 10
			i=$(( $i + 1 ))
			# give up after 50s
			[[ $i -gt 5 ]] && false && break
		done

		display_alert "Host $(mask_ip "$USER_HOST") found" "Run $r out of ${PASSES}" "info";

		# wait for SSHD to come up
		f=1
		while ! nc -zvw3 $USER_HOST 22 &>/dev/null
		do
			sleep 10
			f=$(( $f + 1 ))
			[[ $f -gt 4 ]] && false && break
			display_alert "Probing SSH port on $USER_HOST" "$(date  +%R:%S)" "info"
		done

}



function run_tests
{
r=1
i=1

SUM=0
# run board test loop PASSES time
while [ $r -le ${PASSES} ]
	do

		# wait until you get ping and sshd response
		wait_for_board

		# show error that we can't connect to the hosts sshd
		if [[ $? -ne 0 ]]; then

			display_alert "Can't connect. SSH on $USER_HOST is closed" "$(date  +%R:%S)" "err"

		else

			# otherwise proceed with running test cases
			# read tests
			readarray -t array < <(find $SRC/tests -maxdepth 2 -type f -name '*.bash' | sort)

			# read board information
			get_board_data

			# construct HTML for report
			HEADER_HTML+="\n<tr>"$( [[ ${r} -eq 1 ]] && \
			echo "<td align=right rowspan=$((PASSES+1))>&nbsp;$((x+1))&nbsp;</td>\
			<td colspan=$((COLOUMB+2))>${BOARD_NAME} $(mask_ip "$USER_HOST")</td></td></tr><tr>")"\
			<td align=center>$r/${PASSES}<br><small>$(date  +%R:%S)</small></td>\
			<td>${BOARD_VERSION} (${BOARD_DISTRIBUTION_CODENAME})<br>${BOARD_KERNEL} ${BOARD_IMAGE_TYPE}</td>"

			# run tests
			for u in "${array[@]}"
			do
				unset TEST_OUTPUT
				DATA_ALIGN="center"
				. $u
				[[ $TEST_SKIP != "true" ]] && HEADER_HTML+="<td align=$DATA_ALIGN>$TEST_OUTPUT</td>"
				unset TEST_SKIP
			done
			HEADER_HTML+="</tr>\n"

	fi

	r=$(( $r + 1 ))

done
}
