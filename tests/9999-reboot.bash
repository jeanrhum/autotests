#!/bin/bash
source $SRC/lib/functions.sh

TEST_TITLE="Reboot"
TEST_SKIP="true"
[[ $DRY_RUN == true ]] && return 0

display_alert "$(basename $BASH_SOURCE)" "$(date  +%R:%S)" "info"
display_alert "Rebooting in 3 seconds" "${USER_HOST}" "info"
sleep 3
sshpass -p ${PASS_ROOT} ssh ${USER_ROOT}@${USER_HOST} "reboot" &>/dev/null
sleep 3
i=0
# return error if machine does not come back after 10 seconds
echo -en "[\e[0;32m o.k. \x1B[0m] "
while ping -c1 $USER_HOST &>/dev/null; do echo -n "."; sleep 2; i=$(( $i + 1 )); [[ $i -gt 10 ]] && return 1; done
i=0
echo ""