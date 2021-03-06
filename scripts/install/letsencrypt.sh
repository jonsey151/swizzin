#!/bin/bash
# Let's Encrypt Installa
# nginx flavor by liara
# Copyright (C) 2017 Swizzin
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#

if [[ ! -f /install/.nginx.lock ]]; then
    echo "This script is meant to be used in conjunction with nginx and it has not been installed. Please install nginx first and restart this installer."
    exit 1
fi    

ip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')

echo -e "Enter domain name to secure with LE"
read -e hostname

sed -i "s/server_name _;/server_name $hostname;/g" /etc/nginx/sites-enabled/default

read -p "Is your DNS managed by CloudFlare? (y/n) " yn
case $yn in
    [Yy] )
        cf=yes
        ;;
    [Nn] )
        cf=no
        ;;
    * ) echo "Please answer (y)es or (n)o.";;
esac


if [[ ${cf} == yes ]]; then
    read -p "Does the record for this subdomain already exist? (y/n) " yn
    case $yn in
        [Yy] )
        record=yes
        ;;
        [Nn] )
        record=no
        ;;
        * )
        echo "Please answer (y)es or (n)o."
        ;;
    esac
  

  echo -e "Enter CF API key"
  read -e api

  echo -e "CF Email"
  read -e email

  export CF_Key="${api}"
  export CF_Email="${email}"

  valid=$(curl -X GET "https://api.cloudflare.com/client/v4/user" -H "X-Auth-Email: $email" -H "X-Auth-Key: $api" -H "Content-Type: application/json")
  if [[ $valid == *"\"success\":false"* ]]; then
    message="API CALL FAILED. DUMPING RESULTS:\n$valid"
    echo -e "$message"
    exit 1
  fi

    if [[ ${record} == no ]]; then
        echo -e "Zone Name (example.com)"
        read -e zone
        zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone" -H "X-Auth-Email: $email" -H "X-Auth-Key: $api" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
        addrecord=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records" -H "X-Auth-Email: $email" -H "X-Auth-Key: $api" -H "Content-Type: application/json" --data "{\"id\":\"$zoneid\",\"type\":\"A\",\"name\":\"$hostname\",\"content\":\"$ip\",\"proxied\":true}")
        if [[ $addrecord == *"\"success\":false"* ]]; then
            message="API UPDATE FAILED. DUMPING RESULTS:\n$addrecord"
            echo -e "$message"
            exit 1
        else
            message="DNS record added for $hostname at $ip"
            echo "$message"
        fi
    fi
fi

if [[ ! -f /root/.acme.sh/acme.sh ]]; then
  curl https://get.acme.sh | sh
fi

mkdir -p /etc/nginx/ssl/${hostname}

if [[ ${cf} == yes ]]; then
  /root/.acme.sh/acme.sh --issue --dns dns_cf -d ${hostname} || (echo "ERROR: Certificate could not be issued. Please check your info and try again"; exit 1)
else
  /root/.acme.sh/acme.sh --issue --nginx -d ${hostname} || (echo "ERROR: Certificate could not be issued. Please check your info and try again"; exit 1)
fi
/root/.acme.sh/acme.sh --install-cert -d ${hostname} --key-file /etc/nginx/ssl/${hostname}/key.pem --fullchain-file /etc/nginx/ssl/${hostname}/fullchain.pem --ca-file /etc/nginx/ssl/${hostname}/chain.pem --reloadcmd "service nginx force-reload"

sed -i "s/ssl_certificate .*/ssl_certificate \/etc\/nginx\/ssl\/${hostname}\/fullchain.pem;/g" /etc/nginx/sites-enabled/default
sed -i "s/ssl_certificate_key .*/ssl_certificate_key \/etc\/nginx\/ssl\/${hostname}\/key.pem;/g" /etc/nginx/sites-enabled/default

systemctl reload nginx
