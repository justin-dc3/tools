#!/bin/bash

UUID=$1 && [ -z "${UUID}" ] && echo "Must provide uuid" && exit
SIZE=$2 && [ -z "${SIZE}" ] && SIZE=10000
SENSOR=$(sudo -u postgres psql -h saas-db-coordinator-1.darkcubed.calops -U dark3 -d dark3 -A -t -c "SELECT sensor_uuid FROM collections.sensors WHERE sensor_uuid = '${UUID}' OR account_uuid = '${UUID}' LIMIT 1;") && [ -z "${SENSOR}" ] && echo "Invalid uuid" && exit
ES_OUT="traffic_${SENSOR}.json" && cat /dev/null > ${ES_OUT}
OUT="traffic_${SENSOR}.txt"
LOG="${SENSOR}.log"
QUERY="traffic.json"

echo "$(date +%Y-%m-%d_%H:%M:%S) - Starting traffic" >> ${LOG}

search=$(cat ${QUERY} | sed -e "/after/d" | sed -e "s/SENSOR/${SENSOR}/g" | sed -e "s/SIZE/${SIZE}/g")

result=$(curl -s -u elastic:bdj54q9pnlbbq7j6v5kqbwf6 -k -X POST "https://internal-a25dc161a485311eab7e402c6bb02f10-1599627025.us-east-2.elb.amazonaws.com:9200/traffic-*/_search" -H 'Content-Type: application/json' -d "${search}")
echo "${result}" | jq -c '.aggregations.connections.buckets | .[] | {connection:.key,count:.count,first:.first,last:.last,sent:.sent,received:.received,latest:.latest}' >> ${ES_OUT}
AFTER_SENSOR="$(echo ${result} | jq -r '.aggregations.connections.after_key.sensor')"
AFTER_SOURCE="$(echo ${result} | jq -r '.aggregations.connections.after_key.source')"
AFTER_DEST="$(echo ${result} | jq -r '.aggregations.connections.after_key.dest')"
AFTER_PROTO="$(echo ${result} | jq -r '.aggregations.connections.after_key.proto')"
AFTER_SPORT="$(echo ${result} | jq -r '.aggregations.connections.after_key.sport')"
AFTER_DPORT="$(echo ${result} | jq -r '.aggregations.connections.after_key.dport')"
while [[ "${AFTER_SENSOR}" != "null" ]]; do
   echo "$(date +%Y-%m-%d_%H:%M:%S) - Pulling another ${SIZE} starting with: ${AFTER_SENSOR}/${AFTER_SOURCE}/${AFTER_DEST}/${AFTER_PROTO}/${AFTER_SPORT}/${AFTER_DPORT}..." >> ${LOG}
   search=$(cat ${QUERY} | sed -e "s/AFTER_SENSOR/${AFTER_SENSOR}/g" | sed -e "s/AFTER_SOURCE/${AFTER_SOURCE}/g" | sed -e "s/AFTER_DEST/${AFTER_DEST}/g" | sed -e "s/AFTER_PROTO/${AFTER_PROTO}/g" | sed -e "s/AFTER_SPORT/${AFTER_SPORT}/g" | sed -e "s/AFTER_DPORT/${AFTER_DPORT}/g" | sed -e "s/SENSOR/${SENSOR}/g" | sed -e "s/SIZE/${SIZE}/g")
   result=$(curl -s -u elastic:bdj54q9pnlbbq7j6v5kqbwf6 -k -X POST "https://internal-a25dc161a485311eab7e402c6bb02f10-1599627025.us-east-2.elb.amazonaws.com:9200/traffic-*/_search" -H 'Content-Type: application/json' -d "${search}")
   echo "${result}" | jq -c '.aggregations.connections.buckets | .[] | {connection:.key,count:.count,first:.first,last:.last,sent:.sent,received:.received,latest:.latest}' >> ${ES_OUT}
   AFTER_SENSOR="$(echo ${result} | jq -r '.aggregations.connections.after_key.sensor')"
   AFTER_SOURCE="$(echo ${result} | jq -r '.aggregations.connections.after_key.source')"
   AFTER_DEST="$(echo ${result} | jq -r '.aggregations.connections.after_key.dest')"
   AFTER_PROTO="$(echo ${result} | jq -r '.aggregations.connections.after_key.proto')"
   AFTER_SPORT="$(echo ${result} | jq -r '.aggregations.connections.after_key.sport')"
   AFTER_DPORT="$(echo ${result} | jq -r '.aggregations.connections.after_key.dport')"
done

cat ${ES_OUT} | jq -r '. | .connection.sensor + "|" + .connection.source + "|" + .connection.dest + "|" + .connection.proto + "|" + (.connection.sport|tostring) + "|" + (.connection.dport|tostring) + "|" + (.count.value|tostring) + "|" + (.first.value|tostring) + "|" + (.last.value|tostring) + "|" + (.sent.value|tostring) + "|" + (.received.value|tostring) + "|" + (if .latest.hits.hits[0]._source.score then .latest.hits.hits[0]._source.score else 0 end|tostring) + "|" + (.latest.hits.hits[0]._source.country) + "|" + (.latest.hits.hits[0]._source.location)' > ${OUT}

echo "$(date +%Y-%m-%d_%H:%M:%S) - Done traffic" >> ${LOG}
