#!/bin/bash
# quick script for mounting nfs mounts


NFSIP=192.168.123.123
REMOTEFOLDER=/mnt/vmstore/iso
LOCALFOLDER=/mnt/xeniso

#don't modify below this line.

mkdir -p $LOCALFOLDER
echo "" >> /etc/fstab
echo "# NFS Mounts" >> /etc/fstab
echo "$NFSIP:$REMOTEFOLDER    $LOCALFOLDER      nfs     rsize=8192,wsize=8192,timeo=14,intr" >> /etc/fstab
mount -a