#!/bin/bash

DIR=$(realpath "$(dirname "$0")")

menu() {


HEIGHT=20
WIDTH=70
CHOICE_HEIGHT=12
TITLE="Hysteria v2 Server Manager"
MENU="Choose one of the following options:"

OPTIONS=(1 "Hysteria v2 Management"
         2 "User Management"
	 3 "WARP Management"
	 4 "Advanced"
)

CHOICE=$(dialog --clear \
    --title "$TITLE" \
    --menu "$MENU" \
    $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "${OPTIONS[@]}" \
    3>&1 1>&2 2>&3)

NEED_KEY=1

case $CHOICE in

	1)OPTIONS=("Install Or Update" ""
         	   "Uninstall" ""
         	   "Back" ""
 	  )

          CHOICE=$(dialog --clear \
              --title "$TITLE" \
              --menu "$MENU" \
              $HEIGHT $WIDTH $CHOICE_HEIGHT \
              "${OPTIONS[@]}" \
              3>&1 1>&2 2>&3)

          case $CHOICE in
		
	        "Install Or Update")installing_hy
			;;

		"Uninstall")uninstalling_hy

			;;

		"Back") NEED_KEY=0
	 		;;	
	  esac
	  ;;


        2)OPTIONS=("Users Info" ""
                   "Add User" ""
		   "Modify User" ""
                   "Back" ""
          )

          CHOICE=$(dialog --clear \
              --title "$TITLE" \
              --menu "$MENU" \
              $HEIGHT $WIDTH $CHOICE_HEIGHT \
              "${OPTIONS[@]}" \
              3>&1 1>&2 2>&3)

          case $CHOICE in

                "Users Info")user_info
                        ;;

                "Add User")add_user
                        ;;

                "Modify User") NEED_KEY=0
			;;

                "Back") NEED_KEY=0
                        ;;
          esac
          ;;

        3)OPTIONS=("Install" ""
                   "Uninstall" ""
		   "Change Account Type" ""
		   "Status" ""
                   "Back" ""
          )

          CHOICE=$(dialog --clear \
              --title "$TITLE" \
              --menu "$MENU" \
              $HEIGHT $WIDTH $CHOICE_HEIGHT \
              "${OPTIONS[@]}" \
              3>&1 1>&2 2>&3)

          case $CHOICE in

                "Install")clear
			wget -N -O $DIR/menu.sh https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash $DIR/menu.sh w
			if [ $? -eq 0 ]; then
			yq '.acl.inline += ["warp(geoip:google)","warp(geoip:openai)","warp(geoip:netflix)","warp(35.184.0.0/13)"]' ./etc/hysteria/config.yaml -i -y 
			systemctl restart hysteria-server.service
			sleep 15
			systemctl status hysteria-server.service
			fi
                        ;;

                "Uninstall")clear
			bash $DIR/menu.sh u
                        ;;
	        
		"Change Account Type")clear
			bash $DIR/menu.sh a
			;;

		"Status")clear
			bash $DIR/menu.sh
			;;

                "Back") NEED_KEY=0
                        ;;
          esac
          ;;

        *)clear;;
  
esac
if [[ $NEED_KEY == 1 ]]; then
    read -p "Press any key to return to menu" -n 1 key
fi
menu
}

installing_hy() {
if [ -x "$(command -v hysteria)" ]; then
  check=$(dialog --clear --title "Update Hysteria v2" --inputbox "If you want to update press y [default is no]: " 20 70 3>&1 1>&2 2>&3)
  clear
  if [ $check == "y" ]; then
  mkdir /root/backup
  cp -r /etc/hysteria/* /root/backup/
  bash <(curl -fsSL https://get.hy2.sh/)
  if [ $? -eq 0 ]; then
  cp -r /root/backup/* /etc/hysteria/
  rm -rf /root/backup
  else
  echo "latest version"
  fi
  else
  echo "Hysteria v2 already installed. Skipping installation ..."
  fi
else
  version=$(dialog --title "Install Hysteria v2" --inputbox "Please enter a specific version or if you want the latest version don't : " 20 70 3>&1 1>&2 2>&3)
  obfs=$(dialog --title "Install Hysteria v2" --inputbox "Do you want to use Obfuscation ? [y/N]: " 20 70 3>&1 1>&2 2>&3)
  warp=$(dialog --title "Install Hysteria v2" --inputbox "Do you want to install WARP ? [y/N]: " 20 70 3>&1 1>&2 2>&3)
  #domain=$(dialog --title "Install Hysteria v2" --inputbox "Do you want to install WARP ? [y/N]: " 20 70 3>&1 1>&2 2>&3)
  clear
  if [ ! -z $version ]; then
  bash <(curl -fsSL https://get.hy2.sh/) --version v$version
  else
  bash <(curl -fsSL https://get.hy2.sh/)
  fi
  if [ $? -eq 0 ]; then
  sed -i '/User=/d' /etc/systemd/system/hysteria-server.service
  sed -i '/User=/d' /etc/systemd/system/hysteria-server@.service
  systemctl daemon-reload
  if [[ $obfs == "y" ]]; then
  password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
  yq --arg pass "$password"  '.obfs += {"type": "salamander", "salamander": {"password": $pass}}' $DIR/config.yaml -y | sponge $DIR/config.yaml.new
  fi
  if [[ $warp == "y" ]]; then
  wget -N -O $DIR/menu.sh https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash $DIR/menu.sh w
  yq '.acl.inline += ["warp(geoip:google)","warp(geoip:openai)","warp(geoip:netflix)","warp(35.184.0.0/13)","direct(all)"]' $DIR/config.yaml -y | sponge $DIR/config.yaml.new
  fi
  openssl ecparam -genkey -name prime256v1 -out ca.key
  openssl req -new -x509 -days 36500 -key ca.key -out ca.crt  -subj "/CN=bing.com"
  mv ca.key ca.crt /etc/hysteria/ 
  wget -O /etc/hysteria/geosite.dat https://github.com/bootmortis/iran-hosted-domains/releases/download/202402190026/iran.dat 
  cat $DIR/config.yaml.new
  sleep 2
  read -p "Do you confirm config file ? [y/N]" confirm
  if [[ $confirm == "y" ]]; then
  yq . $DIR/config.yaml.new -y | sponge /etc/hysteria/config.yaml
  systemctl enable hysteria-server.service
  systemctl start hysteria-server.service
  else
  nano $DIR/config.yaml.new
  systemctl enable hysteria-server.service
  systemctl start hysteria-server.service
  fi
  else
  echo "Please check error logs"
  fi
fi
sleep 10
systemctl status hysteria-server.service
}


uninstalling_hy() {
# Ask the user to confirm the uninstallation
confirm=$(dialog --clear --title "Uninstall Hysteria v2" --inputbox  "Are you sure you want to uninstall Hysteria v2? [y/N]: " 20 70 3>&1 1>&2 2>&3)
# Check if hysteria is installed
clear
if [ -x "$(command -v hysteria)" ]; then
if [ $confirm == "y" ]; then
bash <(curl -fsSL https://get.hy2.sh/) --remove
rm -rf /etc/hysteria
userdel hysteria
systemctl daemon-reload
echo "Hysteria v2 uninstalled successfully."
else
echo "Uninstallation canceled."
fi
else
echo "Hysteria v2 is not installed. Nothing to do."
fi
}



user_info() {

U=()
# Loop through each line of the output of the yq -r '.auth.userpass | keys[]' /etc/hysteria/config.yaml command
# This command extracts the keys from the .auth.userpass object in the YAML file
while read -r line; do
# Append the key name and a placeholder value to the array
# You can change the placeholder value to something else if you want
U+=("$line" "")
# Use the < <(command) syntax to pass the output of the command as input to the loop
done < <(yq -r '.auth.userpass | keys[]' /etc/hysteria/config.yaml)
# The rest of the code remains the same as before
USERS=$(dialog --clear \
--title "User Info" \
--menu "Select Users" \
20 70 100 \
"${U[@]}" \
3>&1 1>&2 2>&3)

clear
if [[ $USERS != "" ]]; then
rx_limit=$(jq -r .$USERS.rxlimit $DIR/hysteriadb.json)
prev_traffic=$(jq -r .$USERS.rx $DIR/hysteria.json)
new_traffic=$(curl 'http://127.0.0.1:7687/traffic' | jq -r .$USERS.rx)
if [[ $new_traffic == "null" ]]; then
new_traffic=0
traffic=$(($new_traffic + $prev_traffic))
else
traffic=$(($new_traffic + $prev_traffic))
fi

link=$(jq -r .$USERS.link $DIR/hysteriadb.json)

exp_date=$(jq -r ".$USERS.expdate" $DIR/hysteriadb.json)
start_date=$(jq -r ".$USERS.startdate" $DIR/hysteriadb.json)
end_date=$(date -d "$start_date + $exp_date days" +%Y-%m-%d)
daysleft=$(dateutils.ddiff today "$end_date" -f "%d Days Left")

dialog --title $USERS --msgbox "Link : $link \nTraffin Usage : $(($traffic / 1024 / 1024 / 1024)) GB / $(($rx_limit / 1024 / 1024 / 1024)) GB \nDays : $daysleft " 20 200 2> /dev/null
user_info
fi
}



add_user() (

Update_prev_traffic() {
prev_rx=$(jq -r .$ID.rx $DIR/hysteria.json)
new_rx=$(curl 'http://127.0.0.1:7687/traffic' | jq -r .$ID.rx)
prev_tx=$(jq -r .$ID.tx $DIR/hysteria.json)
if [[ $prev_rx == "null" ]] ; then
prev_rx=0
fi
if [[ $prev_tx == "null" ]] ; then
prev_tx=0
fi
new_tx=$(curl 'http://127.0.0.1:7687/traffic' | jq -r .$ID.tx)
# compare the rx values and update them if they are lower

if [[ $new_rx != "null" ]] ; then
# update the rx value of amirali in prev.json
jq --arg name "$ID" --arg new_rx_edit "$((prev_rx + new_rx))" '.[$name].rx = $new_rx_edit' $DIR/hysteria.json | sponge $DIR/hysteria.json
fi
if [[ $new_tx != "null" ]] ; then
jq --arg name "$ID" --arg new_tx_edit "$((prev_tx + new_tx))" '.[$name].tx = $new_tx_edit' $DIR/hysteria.json | sponge $DIR/hysteria.json
fi
}
#read -p "Please enter the names (separated by space): " -a names
dialog --inputbox "Please enter the names (separated by space): " 20 70 2> /tmp/names.tmp
read -a names < /tmp/names.tmp

add_users() {
for name in "${names[@]}";
do
check=$(yq -r '.auth.userpass | keys[]' /etc/hysteria/config.yaml | grep $name)
if [ -z $check ]; then
exp_date=$(dialog --inputbox "Please enter the expiration date (days) for $name: " 20 70 3>&1 1>&2 2>&3)
rx_limit=$(dialog --inputbox "Please enter the traffic limit for $name: " 20 70 3>&1 1>&2 2>&3)
#read -p "Please enter the expiration date (days) for $name: " exp_date
#read -p "Please enter the traffic limit for $name: " rx_limit
jq --arg date $(date +%Y-%m-%d) --arg name "$name" '.[$name].startdate = $date' $DIR/hysteriadb.json | sponge $DIR/hysteriadb.json
jq --arg date "$exp_date" --arg name "$name" '.[$name].expdate = $date' $DIR/hysteriadb.json | sponge $DIR/hysteriadb.json
jq --arg rxl "$(echo "$rx_limit * 1024 * 1024 * 1024" | bc)" --arg name "$name" '.[$name].rxlimit = $rxl' $DIR/hysteriadb.json | sponge $DIR/hysteriadb.json
# generate a random password
password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15)

# add user with the password to config.yml
yq --arg password "$password" --arg name "$name" '.auth.userpass[$name] = $password' /etc/hysteria/config.yaml -y -i

if [ $? -eq 0 ]; then
#Generate Link
sni=$(dialog --inputbox "Please enter the SNI for $name: " 20 70 "eset.com" 3>&1 1>&2 2>&3)
port=$(dialog --inputbox "Please enter hysteria listening port: " 20 70 443 3>&1 1>&2 2>&3)
#read -p "Please enter your SNI: " sni
#read -p "Enter port: " port
ip=$(ip -4 addr show ens3 | awk '/inet/ {print $2}' | cut -d/ -f1)
port=${port:-443}
pass=$(yq -r .auth.userpass.$name /etc/hysteria/config.yaml)
obf_pass=$(yq -r '.obfs.salamander.password' /etc/hysteria/config.yaml)
clear
if [[ $obf_pass != "null" ]]; then
link="hy2://$name:$pass@$ip:$port?obfs=salamander&obfs-password=$obf_pass&insecure=1&sni=$sni#Hi-$name"
jq --arg name "$name" --arg generated "$link" '.[$name].link = $generated' $DIR/hysteriadb.json | sponge $DIR/hysteriadb.json
echo "hy2://$name:$pass@$ip:$port?obfs=salamander&obfs-password=$obf_pass&insecure=1&sni=$sni#Hi-$name"
#dialog --msgbox "hy2://$name:$pass@$ip:$port?obfs=salamander&obfs-password=$obf_pass&insecure=1&sni=$sni#Hi-$name" 20 200 2> /dev/null
else
link="hy2://$name:$pass@$ip:$port?insecure=1&sni=$sni#Hi-$name"
jq --arg name "$name" --arg generated "$link" '.[$name].link = $generated' $DIR/hysteriadb.json | sponge $DIR/hysteriadb.json
echo "hy2://$name:$pass@$ip:$port?insecure=1&sni=$sni#Hi-$name" 
#dialog --msgbox "hy2://$name:$pass@$ip:$port?insecure=1&sni=$sni#Hi-$name" 20 200 2> /dev/null
fi
else
echo "User $name not Created please check logs"
#dialog --msgbox "User $name not Created please check logs" 20 70 2> /dev/null
fi
else
echo "$name already exist"
fi
done
}
add_users

rm -f /tmp/names.tmp
IDs=$(jq -r 'keys[]' $DIR/hysteriadb.json)
for ID in $IDs1
do
Update_prev_traffic
done

systemctl restart hysteria-server.service

)



generate_links() {

echo "choose one of them"
yq '.auth.userpass | keys[]' /etc/hysteria/config.yaml

read -p "Please enter your name: " name
read -p "Please enter your SNI: " sni
read -p "Enter port: " port

ip=$(ip -4 addr show ens3 | awk '/inet/ {print $2}' | cut -d/ -f1)
port=${port:-443}
pass=$(yq -r .auth.userpass.$name /etc/hysteria/config.yaml)
obf_pass=$(yq -r '.obfs.salamander.password' /etc/hysteria/config.yaml)
if [[ $obf_pass != "null" ]]; then
echo "hy2://$name:$pass@$ip:$port?obfs=salamander&obfs-password=$obf_pass&insecure=1&sni=$sni#Hi-$name"
else
echo "hy2://$name:$pass@$ip:$port?insecure=1&sni=$sni#Hi-$name"
fi

}




# Check if the script is run as root
if [ $(id -u) -ne 0 ]; then
echo "This script must be run as root"
exit 1
else
apt-get install bc moreutils python3-pip jq dialog dateutils curl wget -y && pip install yq
check=$(crontab -l | grep "$DIR/traffic_limit.sh > $DIR/traffic_limit.log")
if [ -z $check ]; then 
crontab -l | { cat; echo "*/5 * * * * $DIR/traffic_limit.sh > $DIR/traffic_limit.log"; } | crontab -
fi
if [ ! -f $DIR/hysteriadb.json ]; then
echo '{}' > $DIR/hysteriadb.json
fi
if [ ! -f $DIR/config.yaml ]; then
echo "config.yaml not exist"
exit 1
fi
fi



menu "$@"
