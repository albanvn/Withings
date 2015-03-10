#! /bin/sh

URLAUTH="https://account.withings.com/connectionuser/account_login?r=https%3A%2F%2Fhealthmate.withings.com"
POSTDATA="email={email}&password={password}&use_authy=&is_admin="
URLDATA="https://babyws.withings.net/cgi-bin/presence?action=get&sessionid={session_id}&deviceid={device_id}"
URLRTMP="rtmp://{private_ip}:1935/{kd_hash}/"
FINALURL="http://fpdownload.adobe.com/strobe/FlashMediaPlayback_101.swf?streamType=live&autoPlay=true&playButtonOverlay=false&src={rtmpurl}"
URLASSOC="https://healthmate.withings.com/index/service/association"
ASSOCDATA="sessionid={session_id}&accountid={account_id}&type=2&enrich=t&action=getbyaccountid"

EMAIL="$1"
PASSWD="$2"
MODE="$3"
CAMINDEX="$4"

test "$EMAIL" = "-h" && echo "USAGE: $0 withings_email withings _password [mode cam_index].\n  mode can be 'rtmp' for rtmp stream or 'flash' for embedded flash player video\n  cam_index is the camera index, if more than 1 camera (default is 1). If cam_index is bad setted, the last camera in array is used" && exit  
test -z "$EMAIL" && test -z "$PASSWD" && echo "You must give email and password as parameter 1 and 2. Aborting" && exit
test -z "$MODE" && MODE="rtmp"
test -z "$CAMINDEX" && CAMINDEX=1

# connect to withings with email and password
data=`echo "$POSTDATA" | sed -e "s/{email}/"$EMAIL"/g" -e "s/{password}/"$PASSWD"/g"`
res=`wget -d "$URLAUTH" --post-data "$data" -O - 2>/dev/null`

# extract accoundId and sessionId
aid=`echo "$res" | grep "accountId" | awk -F"\"" '{print$2;}'`
sid=`echo "$res" | grep  "sessionid" | awk -F"\"" '{print$2;}'`

test -z "$aid" && echo "Cannot find accountId. Aborting" && exit
test -z "$sid" && echo "Cannot find sessionId. Aborting" && exit

# get association info and extract first smart baby monitor deviceId 
data=`echo "$ASSOCDATA" | sed -e "s/{session_id}/"$sid"/g" -e "s/{account_id}/"$aid"/g"`
udata=`wget -O - "$URLASSOC" --post-data "$data" 2>/dev/null` 
did=`echo $udata | tr -d '{}[]' | sed -e "s/,/\n/g" | grep deviceid | head -n $CAMINDEX | tail -n 1 | tr -d '"' | awk -F":" '{print$2;}'`

test -z "$did" && echo "Cannot find deviceId. Aborting" && exit

# get camera connection info
url=`echo "$URLDATA" | sed "s/{session_id}/"$sid"/g" | sed "s/{device_id}/"$did"/g"`
info=`wget -O - "$url" 2>/dev/null | tr '{},' '\n\n\n' | tr -d '"'`

# extract private_ip and kd_hash
pip=`echo "$info" | grep "private_ip" | awk -F":" '{print$2;}'`
kdhash=`echo "$info" | grep "kd_hash" | awk -F"hash:" '{print$2;}'`
url=`echo "$URLRTMP" | sed -e "s/{private_ip}/"$pip"/g" -e "s/{kd_hash}/"$kdhash"/g"`

test -z "$pip" && echo "Cannot find privateIp. Aborting" && exit
test -z "$kdhash" && echo "Cannot find kd_hash. Aborting" && exit

case $MODE in
  rtmp)  
    # show rtmp stream
    echo "$url";;
  flash)
    # show embeded flash player url
    echo "$FINALURL" | sed -e "s%{rtmpurl}%"$url"%g";;
  *)
    echo "Error: parameter 3 can be 'flash' or 'rtmp'. Aborting";;
esac 

