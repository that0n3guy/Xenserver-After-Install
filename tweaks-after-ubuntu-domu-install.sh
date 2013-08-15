#!/bin/bash
#
# Script to run on ubuntu 12.04 domu's after install of the domu
#
#http://askubuntu.com/questions/78682/how-do-i-change-to-the-noop-scheduler
#http://blog.encomiabile.it/2010/04/16/xen-improve-disk-performance-on-domu/
#The below will noop scheduler for only the main linux drive (xvda)

echo "Setting noop scheduler"
if ! echo noop > /sys/block/xvda/queue/scheduler; then
  echo "FATAL: could not setting noop scheduler for main drive"
  exit 1
fi


# The below will set  the scheduler for all drives... I don't want this, only the virtual drive.
#echo "Setting noop scheduler"
#if ! sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*\+/GRUB_CMDLINE_LINUX_DEFAULT="splash quiet elevator=noop"/' /etc/default/grub; then
#  echo "FATAL: could not setting noop scheduler"
#  exit 1
#fi
