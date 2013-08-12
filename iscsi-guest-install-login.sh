#! /bin/bash
# 
# This script will install open-iscsi on ubuntu (tested on 12.04) and login \
#   to a iscsi target given IP and username/password


log_file="/root/iscsi-install-login.log"


function log()
{
  echo -e "$(date +%b\ %d\ %H:%M:%S) iscsi-install-login: $@" >> $log_file
  echo -e "$(date +%b\ %d\ %H:%M:%S) iscsi-install-login: $@"
}

function collectinfo()
{
  #Ask for iscsi username
  echo "Enter the Targets IP address: "
  read -n20 -e ipaddr
  echo

  #Ask for iscsi username
  echo "Enter iscsi username (20char max): "
  read -n20 -e username

  while :; do
    echo -n "Enter iscsi password: "
    read -s password
    echo ""
    echo -n "Please Re-type the iscsi password: "
    read -s password2
    echo ""
    [ "$password" = "$password2" ] && break
    echo "Passwords don't match! Try again."
  done

  log "storing info at $storeinfo"
  log "...remove this file if you don't want that info stored"
  echo username=$username > $storeinfo
  echo password=$password >> $storeinfo
  echo ipaddr=$ipaddr >> $storeinfo
}

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root (or sudo)" 1>&2
   exit 1
fi

if [[ -f /tmp/iscsi-install-login.run ]] ; then
    echo
    echo 'You have previously run this script,' 
    echo '  ...running it again will remove open-iscsi'
    echo '  ...and its config files before reinstalling'
    echo '  ...(so it can start with a clean slate)'
    #ask if they want to continue
    read -p "Are you sure you want to continue (y/n)? " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo
        echo
        log "Attempting to remove open-iscsi"
        if ! apt-get -y --purge remove open-iscsi &> /dev/null ; then
          log "FATAL: failed to remove open-iscsi, try doing 'sudo apt-get --purge remove open-iscsi' manually."
          exit 1
        fi
        rm -f /tmp/iscsi-install-login.run
    else
        echo
        exit
    fi
fi

storeinfo='/root/isci-install-login'

if [[ -f $storeinfo ]] ; then
  echo
  echo "You have previously run this script and have stored ip,"
  echo "username and password..."
  read -p "Do you want to re-use that info? ('n' will allow you to re-enter)[y/n]? " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
      echo
      echo
      log "Loading previously inputted values"
      #restore previous variables
      . $storeinfo
  else
    echo
    collectinfo
  fi
else
  echo
  collectinfo
fi



echo
log "Attempting to install open-iscsi"
if ! apt-get -y install open-iscsi &> /dev/null ; then
  log "FATAL: failed to install open-iscsi, try doing 'sudo apt-get install open-iscsi' manually."
  exit 1
fi

touch /tmp/iscsi-install-login.run

log "Setting node.startup = automatic"
if ! sed -i 's/# node.startup = automatic.*\+/node.startup = automatic/' /etc/iscsi/iscsid.conf; then
  log "FATAL: could not set node.startup = automatic"
  exit 1
fi

log "Setting node.startup = manual"
if ! sed -i 's/node.startup = manual.*\+/# node.startup = manual/' /etc/iscsi/iscsid.conf; then
  log "FATAL: could not set node.startup = manual"
  exit 1
fi

log "Setting node.session.auth.username"
if ! sed -i "s/#node.session.auth.username =.*\+/node.session.auth.username = $username/" /etc/iscsi/iscsid.conf; then
  log "FATAL: could not set node.session.auth.username"
  exit 1
fi

log "Setting node.session.auth.password"
if ! sed -i "s/#node.session.auth.password =.*\+/node.session.auth.password = $password/" /etc/iscsi/iscsid.conf; then
  log "FATAL: could not set node.session.auth.password"
  exit 1
fi

log "Setting discovery.sendtargets.auth.username"
if ! sed -i "s/#discovery.sendtargets.auth.username =.*\+/discovery.sendtargets.auth.username = $username/" /etc/iscsi/iscsid.conf; then
  log "FATAL: could not set discovery.sendtargets.auth.username"
  exit 1
fi

log "Setting discovery.sendtargets.auth.password"
if ! sed -i "s/#discovery.sendtargets.auth.password =.*\+/discovery.sendtargets.auth.password = $password/" /etc/iscsi/iscsid.conf; then
  log "FATAL: could not set discovery.sendtargets.auth.password"
  exit 1
fi

log "Restarting open-iscsi"
service open-iscsi restart
echo

echo "Attempting to discover targets on $ipaddr"
iscsiadm --mode discovery --type sendtargets --portal $ipaddr

echo
echo "Did the above look something like (dates and names will differ):"
echo "$ipaddr:3260,1 iqn.2013-08.com.example:somenamehere"
echo
read -p "(y/n)? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo
else
    log "Something must be wrong w/ your target (or something else)"
    exit
fi

log "Restarting open-iscsi"
service open-iscsi restart
echo

log "logging out of the discovered iscsi (incase we previously logged in)"
iscsiadm --mode node --portal $ipaddr --logout
echo

log "logging into the discovered iscsi"
iscsiadm --mode node --portal $ipaddr --login

echo
echo "If you want to logout of target in the future, run:"
echo "sudo iscsiadm --mode node --portal $ipaddr --logout"
echo

echo 'Run "dmesg | grep sd" to verify your connected.'
echo '  see https://help.ubuntu.com/lts/serverguide/iscsi-initiator.html for more info'
