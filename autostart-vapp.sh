# AutoStart Vapp's that have autostart in description
# Script created by Raido Consultants - http://www.raido.be 
# http://www.virtues.it/2012/01/howto-autostart-xs-vapp/
TAG="autostart"
# helper function
function xe_param()
{
  PARAM=$1
  while read DATA; do
    LINE=$(echo $DATA | egrep "$PARAM")
    if [ $? -eq 0 ]; then
    echo "$LINE" | awk 'BEGIN{FS=": "}{print $2}'
    fi
  done
} # Get all Applicances
sleep 20
VAPPS=$(xe appliance-list | xe_param uuid) for VAPP in $VAPPS; do
  echo "Raido AutoStart : Checking vApp $VAPP"
  VAPP_TAGS="$(xe appliance-param-get uuid=$VAPP param-name=name-description)" if [[ $VAPP_TAGS == *$TAG* ]]
    then
    echo "starting vApp $VAPP"
    xe appliance-start uuid=$VAPP
    sleep 20
  fi
done