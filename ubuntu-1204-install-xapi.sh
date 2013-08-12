#!/bin/bash
log_file="/root/xapi_install.log"

function log()
{
	echo -e "$(date +%b\ %d\ %H:%M:%S) $(hostname -s) install-xapi: $@" >> $log_file
	echo -e "$(date +%b\ %d\ %H:%M:%S) $(hostname -s) install-xapi: $@"
}

if !  dpkg --get-selections | grep  -i xen-hypervisor &> /dev/null ; then
	log "Xen Hypervisor not found - attempting to install Xen"
	if ! apt-get -y install xen-hypervisor &> /dev/null ; then
		log "FATAL: failed to install Xen Hypervisor"
		exit 1
	fi
	
	# Delay this till later... since it tends to boot loop.
	# log "Setting Xen as default boot entry"
	# if !  sed -i 's/GRUB_DEFAULT=.*\+/GRUB_DEFAULT="Xen 4.1-amd64"/' /etc/default/grub; then
	# 	log "FATAL: failed to set Xen as d"
	# 	exit 1
	# fi
	
	log "Disabling Apparomor"
	if ! sed -i 's/GRUB_CMDLINE_LINUX=.*\+/GRUB_CMDLINE_LINUX="apparmor=0"/' /etc/default/grub; then
		log "FATAL: could not disable apparmor"
		exit 1
	fi

	log "Setting dom0 memory and vcpu"
	if  ! sed -i '/GRUB_CMDLINE_LINUX="apparmor=0"/ a\GRUB_CMDLINE_XEN="dom0_mem=1G,max:1G dom0_max_vcpus=1"' /etc/default/grub  ; then
		log "FATAL: failed to set dom0 memory and vcpu"
	fi
	
	log "Updating GRUB"
	if ! update-grub &> /dev/null; then
		log "FATAL: could not oupdate GRUB"
		exit 1
	fi
	
	log "Reboot REQUIRED. REBOOTing NOW to activate Xen. RUN THIS SCRIPT AGAIN to complete installation"
	reboot
	exit 0
fi

if dpkg --get-selections | grep  -i xen-hypervisor &> /dev/null  && ! dpkg --get-selections | grep xcp-xapi &> /dev/null ; then

	log "Installing xcp-xapi"
	if ! apt-get -y install xcp-xapi; then
		log "FATAL: failed to install XCP-XAPI"
		exit 1
	fi
	
	log "Setting XAPI as the default toolstack"
	if ! echo 'TOOLSTACK=xapi' > /etc/default/xen ; then
		log "FATAL: could not set XAPI as the default toolstack"
		exit 1
	fi
	
	log "Diabling XEND from starting"
	if !  sed -i -e 's/xend_start$/#xend_start/' -e 's/xend_stop$/#xend_stop/' /etc/init.d/xend; then
		log "FATAL: failed to diable xend from /etc/init.d/xend"
		exit 1
	fi
	
	log "Disabling service xendomains"
	if ! update-rc.d xendomains disable &> /dev/null ; then
		log "FATAL: could not diable service xendomains"
		exit 1
	fi	
	
	log "Fixing QEMU keymaps location"
	mkdir /usr/share/qemu 
	ln -s /usr/share/qemu-linaro/keymaps /usr/share/qemu/keymaps
	
	log "Configuring bridge interface on eth0"
	if ! sed -i -e 's/eth0/xenbr0/' /etc/network/interfaces ; then
		log "FATAL: could not set bridge on interface eth0"
		exit 1
	fi
	
	if ! echo -e "\tbridge_ports eth0\niface eth0 inet manual" >> /etc/network/interfaces ; then
		log "FATAL:  could not set bridge on interface eth0"
		exit 1
	fi

	log "Setting default networking to bridge"
	if ! echo "bridge" > /etc/xcp/network.conf; then
		log "FATAL: could not set deafult networking to bridge"
		exit 1
	fi

	log "Setting Xen as default boot entry"
	if !  sed -i 's/GRUB_DEFAULT=.*\+/GRUB_DEFAULT="Xen 4.1-amd64"/' /etc/default/grub; then
		log "FATAL: failed to set Xen as d"
		exit 1
	fi

	log "Updating GRUB... Again"
	if ! update-grub &> /dev/null; then
		log "FATAL: could not oupdate GRUB"
		exit 1
	fi

	# overwrite the file and add new lines.
	#    Ref: http://ubuntuforums.org/archive/index.php/t-2158441.html
	log "Fixing /etc/pam.d/xapi so XenCenter works"
	if ! echo '#%PAM-1.0' > /etc/pam.d/xapi; then
		log "FATAL: could not set /etc/pam.d/xapi, first line"
		exit 1
	fi

	if ! echo 'auth include common-auth' >> /etc/pam.d/xapi; then
		log "FATAL: could not set /etc/pam.d/xapi, second line"
		exit 1
	fi

	if ! echo 'account include common-auth' >> /etc/pam.d/xapi; then
		log "FATAL: could not set /etc/pam.d/xapi, third line"
		exit 1
	fi
	
	if ! echo 'password include common-auth' >> /etc/pam.d/xapi; then
		log "FATAL: could not set /etc/pam.d/xapi, Last (fourth) line"
		exit 1
	fi
    
  log "Your /etc/pam.d/xapi should now look like
    #%PAM-1.0
    auth include common-auth
    account include common-auth
    password include common-auth"
	
	log "XAPI setup. REBOOTing now to activate XAPI"
	reboot
	exit 0
fi
