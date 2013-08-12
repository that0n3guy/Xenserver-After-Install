Xenserver-After-Install
=======================

This repository contains some scripts that I use when installing/using xenserver (or xcp 1.6...).
Most of these are meant to be run once on clean installs.  

Below is a quick description of the scripts:

##xenserver-tweaks-after-dom0-install.sh
I run this script right after installing xenserver.  I do this on Dom0.  It does the following:
   - stop iptables and stop it from starting up at boot
   - remove the default local storage repository
   - create a new local repository that is ext based http://support.citrix.com/article/ctx116324
   - turn on NFS so it starts at boot
   - export the local repository via NFS (for easy backup/snapraid)
   - configure portmap and make it start at boot
   - adds a autostart script so that any vapp with "autostart" in the description will \ 
       autostart on boot
       
##ubuntu-1204-install-xapi
You can run this script on ubuntu 12.04 server to install xapi on it.... making it similar to xenserver 6.  
There are issues w/ xapi on ubuntu that I ran into, so I stopped working on this and went with xenserver instead...
but this should work.

##tweaks-after-ubuntu-domu-install
This has some tweaks for ubuntu domU's... run this after installing ubuntu in domU

##mount-remote-nfs
I use this to quickly and easily mount nfs on a domU.  Tested in ubuntu 12.04 but probably works in most linux distros

##iscsi-guest-install-login
Installs needed files under ubuntu 12.04 and will login to a iscsi target (based on IP, username, password).

##autostart-vapp
A rc.local script that will autostart vapp's automatically on boot if they have "autostart" in the description of the vapps. 
Added to dom0 for your in xenserver-tweaks-after-dom0-install.sh. Found this on: http://www.virtues.it/2012/01/howto-autostart-xs-vapp/

#Notes from making the scripts

##Manual Steps - much of this is automated in the above scripts. 
###1. Install XCP

###2. Decide how you want to structure disks
-  NFS on XCP: http://www.theurbanpenguin.com/citrix/cxsnfs.html (you can do the iptables differently, see below)
IPTables: 
- allow ports: http://pario.no/2008/01/15/allow-nfs-through-iptables-on-a-redhat-system/ , http://blogs.citrix.com/2009/01/26/how-to-configure-an-nfs-based-iso-sr-using-local-storage-on-a-xenserver5-host/
- [my solution since my router has a firewall] disable iptables (see the top of http://wiki.xen.org/wiki/NagiosXCP )

- partition extra drives
      fdisk /dev/sdb
        n
        p
        1
        enter
        enter
        w

- format patition
      mkfs.ext3 /dev/sdb1

- mount the new partition and create 2 folders for nfs
      #get UUID with:
      blkid
    
      mkdir /mnt/disk1
      echo "" >> /etc/fstab
      echo "#extra disks/partitions" >> /etc/fstab
      echo "UUID=10ed479c-f122-4c59-9313-293b22d7c769 /mnt/disk1 ext4 defaults 0 2" >> /etc/fstab
      mount -a
      mkdir /mnt/disk1/{vdisk,iso}

- disable iptables:
      /etc/rc.d/init.d/iptables stop
      chkconfig --del iptables

- Configure portmap
      sed -i 's/PMAP_ARGS=.*\+/PMAP_ARGS=""/' /etc/sysconfig/portmap
      chkconfig portmap on

- make sure nfs starts on startup & start it
      chkconfig --levels 235 nfs on 
      service nfs start
      service nfs restart

- make portmap starts
      service portmap start
      service portmap restart


- configure nfs exports, edit: /etc/exports
      echo "/mnt/disk1/vdisk        192.168.1.248(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
      echo "/mnt/disk1/iso        192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
      
      exportfs -a

(192.168.1.248 is this xcp servers IP address, 192.168.1.0/24 makes it so that the whole IP range can access the folder)


- check that you have the nfs exports
      showmount -e 192.168.1.248

- create a shutdown script to unmount nfs before nfs server shutsdown but after vm's stop.  Otherwise the server will hang on shutdown/restart
    
    wget the earlynetfs to /etc/init.d/earlynetfs 
    
    chmod +x /etc/init.d/earlynetfs
    chkconfig --add earlynetfs


- verify that the script is in the right sections (rc0 and rc6)
    find /etc/rc.d -name "*earlynetfs*" -print
    chkconfig --list

###3. Add Storage to Xencenter
- NFS: end of this video: http://www.theurbanpenguin.com/citrix/cxsnfs.html
- Local: http://support.citrix.com/article/CTX121313

###4. Installing VM
- if console won't work: http://support.citrix.com/article/CTX119906

###5. tweaks
- to limit the dom0 cpu's and memory, set it in extlinux.conf in /boot

###5. mount NFS on ubuntu 12.04
    mount -v 192.168.1.5:/mnt/vmstore/iso /mnt/sriso
    #on server with port range: /mnt/vmstore/iso        192.168.1.0/24(rw,nohide,sync,no_sub...etc...

    #custom - fstab nfs mounts
    192.168.1.5:/mnt/vmstore/iso    /mnt/sriso      nfs     rsize=8192,wsize=8192,timeo=14,intr

###6. Adding iscsi target on xcp

    yum --enablerepo=base install scsi-target-utils
    
    cat >> /etc/tgt/targets.conf <EOF
    
    
    <target iqn.2013-08.com.vhome:olddell500g>
        backing-store=/dev/sdb2 
        allow-in-use yes
        incominguser iscsiadm iscsiadm123
    </target>
    
    
    EOF
    
    service tgtd restart
    chkconfig tgtd on


####The below does something similar to the above, but is not permanent:
    #http://grantmcwilliams.com/item/553-creating-an-iscsi-target-on-xen-cloud-platform-11
    #List active targets
    tgtadm --lld iscsi --mode target --op show
    
    #Create a new target device
    tgtadm --lld iscsi --mode target --op new --tid=1 --targetname iqn.2013-08.com.vhome:olddell500g
    tgtadm --lld iscsi --mode logicalunit --op new --tid=1 --lun=1 --backing-store=/dev/sdb
    
    #access control
    #http://fedoraproject.org/wiki/Scsi-target-utils_Quickstart_Guide
    tgtadm --lld iscsi --mode target --op bind --tid=1 -I ALL
    OR
    tgtadm --lld iscsi --mode account --op new --user ''usernamehere'' --password ''passwordhere''
    tgtadm --lld iscsi --mode account --op bind --tid 1 --user ''consumer''
    or
    tgtadm --lld iscsi --mode target --op bind --tid=1 --initiator-address=ipaddresshere
    
    #if you want to delete
    tgtadm --lld iscsi --mode logicalunit --op delete --tid=1 --lun=1
    tgtadm --lld iscsi --mode target --op delete --tid=1 
    tgtadm --lld iscsi --mode account --op delete --user ''usernamehere''





#More Notes: 
####creating Templates:
http://invalidlogic.com/2012/05/01/deploying-ubuntu-12-04-on-xenserver-made-easy/
script at the bottom: http://grantmcwilliams.com/item/579-how-to-createdelete-xcp-templates

####Converting HVM to PV:
http://invalidlogic.com/2012/05/01/deploying-ubuntu-12-04-on-xenserver-made-easy/
and http://www.xenlens.com/install-ubuntu-12-04-server-on-citrix-xenserver-6-0-2/
(create a batch script or writeup)


#Random Notes

###Fix openvpn tunneling on ubuntu 12.04 (on amahi)
- script on amahi forums that I made
    https://forums.amahi.org/viewtopic.php?p=26280#p26280

###ssh tunnel through soxy proxy
    ssh -D 8080 -C -N root@ip.addr.here

###List all the kernels
    dpkg --list | grep linux-image +

###VNC notes from someplace... this might be old..:
    # vnc-server.conf
    
    start on runlevel [2345]
    stop on runlevel [016]
    
    post-start script
            su vmmythbox -c '/usr/bin/vncserver :1 -geometry 1024x768'
    end script
    
    post-stop script
            su vmmythbox -c '/usr/bin/vncserver -kill :1'
    end script
    
    #End of File
    
###Tomato (router) dns tweaks
    strict-order
    local-ttl=1
    address=/vhome.com/192.168.1.11
    address=/router/192.168.1.1


