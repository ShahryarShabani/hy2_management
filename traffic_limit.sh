#!/bin/bash

DIR=$(realpath "$(dirname "$0")")

Update_prev_traffic() {
prev_rx=$(jq -r .$Id.rx $DIR/hysteria.json)
new_rx=$(curl 'http://127.0.0.1:7687/traffic' | jq -r .$Id.rx)
prev_tx=$(jq -r .$Id.tx $DIR/hysteria.json)
new_tx=$(curl 'http://127.0.0.1:7687/traffic' | jq -r .$Id.tx)
# compare the rx values and update them if they are lower
if [ $prev_rx == "null" ] ; then
prev_rx=0
fi
if [ $prev_tx == "null" ] ; then
prev_tx=0
fi
if [ $new_rx != "null" ]; then
# update the rx value of amirali in prev.json
jq --arg name "$Id" --arg new_rx_edit "$((prev_rx + new_rx))" '.[$name].rx = $new_rx_edit' $DIR/hysteria.json | sponge $DIR/hysteria.json
jq --arg name "$Id" --arg new_tx_edit "$((prev_tx + new_tx))" '.[$name].tx = $new_tx_edit' $DIR/hysteria.json | sponge $DIR/hysteria.json
else
echo "no updates"
fi
}



IDs=$(yq -r '.auth.userpass | keys[]' /etc/hysteria/config.yaml)
for ID in $IDs
do
echo "-------------------------------------"
echo "-------------------------------------"
echo "                $ID                  "
echo "-------------------------------------"
echo "-------------------------------------"

#Check Traffic

traffic_limit=$(jq -r .$ID.rxlimit $DIR/hysteriadb.json)
prev_traffic=$(jq -r .$ID.rx $DIR/hysteria.json)
new_traffic=$(curl 'http://127.0.0.1:7687/traffic' | jq -r .$ID.rx)
if [ $new_traffic == "null" ]; then
new_traffic=0
traffic=$(($new_traffic + $prev_traffic))
else
traffic=$(($new_traffic + $prev_traffic))
fi
if [ $traffic_limit != "null" ] && [ "$traffic" -ge "$traffic_limit" ]; then
yq "del(.auth.userpass.$ID)" /etc/hysteria/config.yaml -y -i
IDss=$(yq -r '.auth.userpass | keys[]' /etc/hysteria/config.yaml)
for Id in $IDss
do
Update_prev_traffic
done
jq --arg name "$ID" --arg new_rx_edit "0" '.[$name].rx = $new_rx_edit' $DIR/hysteria.json | sponge $DIR/hysteria.json
jq --arg name "$ID" --arg new_tx_edit "0" '.[$name].tx = $new_tx_edit' $DIR/hysteria.json | sponge $DIR/hysteria.json
systemctl restart hysteria-server.service
echo "$ID Traffic is Finished"
else
echo "$ID traffic is not finished"
fi

#Check expiration date
exp_date=$(jq -r ".$ID.expdate" $DIR/hysteriadb.json)
start_date=$(jq -r ".$ID.startdate" $DIR/hysteriadb.json)
if [ $start_date != "null" ]; then
end_date=$(date -d "$start_date + $exp_date days" +%Y-%m-%d)
expired=$(date -d "$end_date" +%s)
now=$(date +%s)
if [ "$expired" -le $now ]; then
yq "del(.auth.userpass.$ID)" /etc/hysteria/config.yaml -y -i
IDss=$(yq -r '.auth.userpass | keys[]' /etc/hysteria/config.yaml)
for Id in $IDss
do
Update_prev_traffic
done
jq --arg name "$ID" --arg new_rx_edit "0" '.[$name].rx = $new_rx_edit' $DIR/hysteria.json | sponge $DIR/hysteria.json
jq --arg name "$ID" --arg new_tx_edit "0" '.[$name].tx = $new_tx_edit' $DIR/hysteria.json | sponge $DIR/hysteria.json
systemctl restart hysteria-server.service
echo "$ID Expired"
else
echo "$ID not expired"
fi
else
echo "no expired date found"
fi
done
