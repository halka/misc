#!/bin/bash
apt update;
apt full-upgrade -y;
apt dist-upgrade -y;
rpi-update -y;
apt autoremove -y;
apt autoclean;
reboot
