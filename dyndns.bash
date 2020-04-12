#!/bin/bash

auth_email="Your Cloudflare Email"             # The email used to login 'https://dash.cloudflare.com'
auth_key="Your Auth Key"   # Top right corner, "My profile" > "Global API Key"
zone_identifier="The zone identifier" # Can be found in the "Overview" tab of your domain
record_name="sub.domain.com"         # Which record you want to be synced
proxy=true                                        # Set the proxy to true or false 

#------------------------------------------
# Check if we have an IP on wwan0 
ip=$(curl https://api.ipify.org)

#------------------------------------------
# Seek for the A record
#------------------------------------------
echo " Check Initiated"
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json")

#------------------------------------------
# Check if the domaine has an A record
#------------------------------------------
if [[ $record == *"\"count\":0"* ]]; then
  message=" Record does not exist! (${ip} for ${record_name})"
  >&2 echo -e "${message}"
  notify "${message}"
  exit 1
fi

#------------------------------------------
# Get the existing IP 
#------------------------------------------
old_ip=$(echo "$record" | grep -Po '(?<="content":")[^"]*' | head -1)
# Compare if they're the same
if [ $ip == $old_ip ]; then
  message=" IP ($ip) for $record_name has not changed."
  echo "${message}"
  exit 0
fi

#------------------------------------------
# Set the record identifier from result
#------------------------------------------
record_identifier=$(echo "$record" | grep -Po '(?<="id":")[^"]*' | head -1)

#------------------------------------------
# Change the IP@Cloudflare using the API
#------------------------------------------
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                     -H "X-Auth-Email: $auth_email" \
                     -H "X-Auth-Key: $auth_key" \
                     -H "Content-Type: application/json" \
              --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"proxied\":${proxy},\"name\":\"$record_name\",\"content\":\"$ip\"}")

#------------------------------------------
# Report the status
#------------------------------------------
case "$update" in
*"\"success\":false"*)
  message="$ip DDNS update failed for $record_identifier ($ip). Update $update"
  >&2 echo -e "${message}"
  exit 1;;
*)
  message="$ip DDNS $record_name updated."
  echo "${message}"
  exit 0;;
esac