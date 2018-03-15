#!/bin/bash
#v10.0 final
exec 2> /dev/null
if [ $# -lt 2 ]; then exit; fi

DEF_INTERFACE=$1 # first WAN interface
FAILOVER_INTERFACE=$2 # second WAN interface
NOW_GW_FILEINFO="/etc/network/failover.info" # file for display current active gw
PING_COUNT_FILE="/etc/network/failover.pingcount" # file for set count of ping packets
PING_INTERVAL_MAX="/etc/network/failover.pingintervalmax" # file for set max interval time of ping packets

if [ ! -f $NOW_GW_FILEINFO ]; then touch $NOW_GW_FILEINFO; fi
if [ ! -f $PING_COUNT_FILE ]; then touch $PING_COUNT_FILE; fi
if [ ! -f $PING_INTERVAL_MAX ]; then touch $PING_INTERVAL_MAX; fi


while [[ -z "$(route | grep default | awk '{print $8}')" ]] # if you launching this script on system startup - wait when routes will be set
do
  sleep 1
done

if [[ ! "$(cat $NOW_GW_FILEINFO)" == "$(route | grep default | awk '{print $8}')" ]]; then
  echo -e "$(route | grep default | awk '{print $8}')" > $NOW_GW_FILEINFO
fi

### default value of ping opts
if [[ -z "$(cat $PING_COUNT_FILE)" ]]; then echo 20 > $PING_COUNT_FILE; fi
if [[ -z "$(cat $PING_INTERVAL_MAX)" ]]; then echo 0.1 > $PING_INTERVAL_MAX; fi
###

while true; do
              internal_checking_ip=$(ifconfig $DEF_INTERFACE | grep -o 'destination [0-9][0-9.]*') # get default gw for main WAN
              external_checking_ip=$(ifconfig $FAILOVER_INTERFACE | grep -o 'destination [0-9][0-9.]*') # get default gw for second WAN
              checking_ip=${internal_checking_ip#destination } # get clean gw IP for main WAN
              external_checking_ip=${external_checking_ip#destination } # get clean gw IP for second WAN
              if [[ -n "$checking_ip" ]]; then # if first gw is exist, than ping second gw
                       if [[ -n "external_checking_ip" ]]; then
                       checking_ip=$(ping -i$(cat $PING_INTERVAL_MAX) -q -n -I $DEF_INTERFACE -c$(cat $PING_COUNT_FILE) $external_checking_ip)
                       echo "$checking_ip"  | grep -q "100% packet loss" && checking_ip= # clean var-indicator
                               if [[ -n "$checking_ip" ]]; then # if all ok - calculate loss packets, and if it more than 5 - clean var-indicator
                                        checking_ip=$(ping -i$(cat $PING_INTERVAL_MAX) -q -n -I $DEF_INTERFACE -c$(cat $PING_COUNT_FILE) $external_checking_ip | grep -oP '\d+(?=% packet loss)')
                                        if [ "$checking_ip" -gt "5" ]; then checking_ip= ; fi
                               fi
                       fi
              fi

              if [[ -z "$checking_ip" ]]; then # if var-indicator clean - switch WAN
                       if [[ "$(cat $NOW_GW_FILEINFO)" == "$DEF_INTERFACE" ]] ; then
                                  echo -e "$FAILOVER_INTERFACE" > $NOW_GW_FILEINFO
                                  ip route replace default dev $(cat $NOW_GW_FILEINFO)
                       fi
                 elif [[ "$(cat $NOW_GW_FILEINFO)" == "$FAILOVER_INTERFACE" ]] ; then
                                  echo -e "$DEF_INTERFACE" > $NOW_GW_FILEINFO
                                  ip route replace default dev $(cat $NOW_GW_FILEINFO)
              fi

done
