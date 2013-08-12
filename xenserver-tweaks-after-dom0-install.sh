#!/bin/bash
#script to run right after xcp 1.6 / xenserver 6 install
#
# This scripte will:
#   - stop iptables and stop it from starting up at boot
#   - remove the default local storage repository
#   - create a new local repository that is ext based http://support.citrix.com/article/ctx116324
#   - turn on NFS so it starts at boot
#   - export the local repository via NFS (for easy backup/snapraid)
#   - configure portmap and make it start at boot
#   - adds a autostart script so that any vapp with "autostart" in the description will \ 
#       autostart on boot
#   
#    @todo - Add error checking and prevent from running twice.

#Variables - Set them as you need them
DEVICE=/dev/sda3  #by default, you won't need to change this
NEWSRTITLE="Local EXT3 (shared)"
EXPORTIP="192.168.123.0/24"



#don't change below this line

HOSTUUID=$(xe host-list --minimal)
SRUUID=$(xe sr-list type=lvm --minimal)
PBDUUID=$(xe pbd-list sr-uuid=$SRUUID --minimal)
xe pbd-unplug uuid=$PBDUUID
xe sr-destroy uuid=$SRUUID
xe sr-create content-type="Local SR" type=ext device-config-device=$DEVICE shared=true name-label="Local EXT3 (shared)" host-uuid=$HOSTUUID

EXTUUID=$(xe sr-list type=ext --minimal)


/etc/rc.d/init.d/iptables stop
chkconfig --del iptables

sed -i 's/PMAP_ARGS=.*\+/PMAP_ARGS=""/' /etc/sysconfig/portmap
chkconfig portmap on

chkconfig --levels 235 nfs on 
service nfs start
service nfs restart

service portmap start
service portmap restart

echo "/var/run/sr-mount/$EXTUUID        $EXPORTIP(rw,async,no_subtree_check,no_root_squash)" >> /etc/exports
exportfs -a

echo showmount -e $EXPORTIP

echo "" >> /etc/rc.d/rc.local
wget --output-document=autostart-deletme http://pastebin.com/raw.php?i=pxSGuVEA 
cat autostart-deletme >> /etc/rc.d/rc.local
rm -f autostart-deletme