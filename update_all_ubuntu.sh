#!/bin/bash

# MIT License
# 
# Copyright (c) 2025 [halka]
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


WAITING_FOR_REBOOT=${1:-10}
# Define ANSI color codes
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_NC='\033[0m' # No Color (reset)

apt update;
apt full-upgrade -y;
apt dist-upgrade -y;
do-release-upgrade -c;
apt autoremove -y;
apt autoclean;

read -p "Do you want to reboot? (Y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    for i in $(seq $WAITING_FOR_REBOOT -1 0); 
    do  
	if (( i <= 3 )); then
            CURRENT_COLOR="${COLOR_RED}"
        elif (( i <= 5 )); then
            CURRENT_COLOR="${COLOR_YELLOW}"
        else
            CURRENT_COLOR="${COLOR_NC}" # Default to no color
        fi  
        echo -ne "\r${CURRENT_COLOR}Reboot in $i Seconds...${COLOR_NC}"
	sleep 1
    done
    echo -ne "\rreboot now!"
    #reboot
else
    echo "Without reboot."
    exit 0
fi
