#!/bin/bash

UUID=$1 && [ -z "${UUID}" ] && echo "Must provide uuid" && exit
SIZE=$2 && [ -z "${SIZE}" ] && SIZE=10000
SENSOR=$(sudo -u postgres psql -h saas-db-coordinator-1.darkcubed.calops -U dark3 -d dark3 -A -t -c "SELECT sensor_uuid FROM collections.sensors WHERE sensor_uuid = '${UUID}' OR account_uuid = '${UUID}' LIMIT 1;") && [ -z "${SENSOR}" ] && echo "Invalid uuid" && exit
ES_OUT="traffic_raw_${SENSOR}.json" && cat /dev/null > ${ES_OUT}
OUT="traffic_raw_${SENSOR}.txt"
LOG="${SENSOR}.log" && cat /dev/null > ${LOG}
QUERY="traffic-raw.json"

echo "$(date +%Y-%m-%d_%H:%M:%S) - Starting traffic raw dump" >> ${LOG}

search=$(cat ${QUERY} | sed -e "s/SENSOR/${SENSOR}/g" | sed -e "s/SIZE/${SIZE}/g")

result=$(curl -s -u elastic:bdj54q9pnlbbq7j6v5kqbwf6 -k -X POST "https://internal-a25dc161a485311eab7e402c6bb02f10-1599627025.us-east-2.elb.amazonaws.com:9200/traffic-*/_search?scroll=5m" -H 'Content-Type: application/json' -d "${search}")
echo "${result}" | jq -c '.hits.hits | .[] | ._source' >> ${ES_OUT}
SCROLL_ID="$(echo ${result} | jq -r '._scroll_id')"
while [[ "${SCROLL_ID}" != "null" ]]; do
   echo "$(date +%Y-%m-%d_%H:%M:%S) - Pulling another ${SIZE}" >> ${LOG}
   search="{ \"scroll\" : \"5m\", \"scroll_id\" : \"${SCROLL_ID}\" }"
   result=$(curl -s -u elastic:bdj54q9pnlbbq7j6v5kqbwf6 -k -X POST "https://internal-a25dc161a485311eab7e402c6bb02f10-1599627025.us-east-2.elb.amazonaws.com:9200/_search/scroll" -H 'Content-Type: application/json' -d "${search}")
   echo "${result}" | jq -c '.hits.hits | .[] | ._source' >> ${ES_OUT}
   SCROLL_ID="$(echo ${result} | jq -r '._scroll_id')"
done

cat ${ES_OUT} | jq -r '. | .sensor + "|" + .src + "|" + .dst + "|" + .proto + "|" + (.sport|tostring) + "|" + (.dport|tostring) + "|" + .seen + "|" + (.score|tostring) + "|" + (.sent|tostring) + "|" + (.recv|tostring) + "|" + .country + "|" + .location' > ${OUT}

echo "$(date +%Y-%m-%d_%H:%M:%S) - Done traffic raw" >> ${LOG}
