#!/bin/bash

cur_path=$(pwd)
echo "Writing hosts to $cur_path"
# load user configuration
source userconfig/configuration.sh
echo "[duts]" > $cur_path/hosts
sudo nmap --exclude $EXCLUDE --open -sn ${SUBNET} -oG - | awk '/Up$/{print $2}' | sort >> $cur_path/hosts
ansible duts -a "apt update " -u root
ansible duts -a "apt -y -qq upgrade " -u root
ansible duts -a "reboot " -u root
