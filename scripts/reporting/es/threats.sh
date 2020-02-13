#!/bin/bash

UUID=$1 && [ -z "${UUID}" ] && echo "Must provide uuid" && exit
SIZE=$2 && [ -z "${SIZE}" ] && SIZE=10000
SENSOR=$(sudo -u postgres psql -h saas-db-coordinator-1.darkcubed.calops -U dark3 -d dark3 -A -t -c "SELECT sensor_uuid FROM collections.sensors WHERE sensor_uuid = '${UUID}' OR account_uuid = '${UUID}' LIMIT 1;") && [ -z "${SENSOR}" ] && echo "Invalid uuid" && exit
ES_OUT="threats_${SENSOR}.json" && cat /dev/null > ${ES_OUT}
OUT="threats_${SENSOR}.txt"
LOG="${SENSOR}.log"
QUERY="threats.json"

echo "$(date +%Y-%m-%d_%H:%M:%S) - Starting threats" >> ${LOG}

search=$(cat ${QUERY} | sed -e "/after/d" | sed -e "s/SENSOR/${SENSOR}/g" | sed -e "s/SIZE/${SIZE}/g")
result=$(curl -s -u elastic:bdj54q9pnlbbq7j6v5kqbwf6 -k -X POST "https://internal-a25dc161a485311eab7e402c6bb02f10-1599627025.us-east-2.elb.amazonaws.com:9200/threats-*/_search" -H 'Content-Type: application/json' -d "${search}")
echo "${result}" | jq -c '.aggregations.threats.buckets | .[] | {threat:.key,count:.count,first:.first,last:.last,latest:.latest}' >> ${ES_OUT}
AFTER_SENSOR="$(echo ${result} | jq -r '.aggregations.threats.after_key.sensor')"
AFTER_THREAT="$(echo ${result} | jq -r '.aggregations.threats.after_key.threat')"
while [[ "${AFTER_SENSOR}" != "null" ]]; do
   echo "$(date +%Y-%m-%d_%H:%M:%S) - Pulling another ${SIZE} starting with: ${AFTER_SENSOR}/${AFTER_THREAT}..."
   search=$(cat ${QUERY} | sed -e "s/AFTER_SENSOR/${AFTER_SENSOR}/g" | sed -e "s/AFTER_THREAT/${AFTER_THREAT}/g" | sed -e "s/SENSOR/${SENSOR}/g" | sed -e "s/SIZE/${SIZE}/g")
   result=$(curl -s -u elastic:bdj54q9pnlbbq7j6v5kqbwf6 -k -X POST "https://internal-a25dc161a485311eab7e402c6bb02f10-1599627025.us-east-2.elb.amazonaws.com:9200/threats-*/_search" -H 'Content-Type: application/json' -d "${search}")
   echo "${result}" | jq -c '.aggregations.threats.buckets | .[] | {threat:.key,count:.count,first:.first,last:.last,latest:.latest}' >> ${ES_OUT}
   AFTER_SENSOR="$(echo ${result} | jq -r '.aggregations.threats.after_key.sensor')"
   AFTER_THREAT="$(echo ${result} | jq -r '.aggregations.threats.after_key.threat')"
done

cat ${ES_OUT} | jq -r '. | .threat.sensor + "|" + .threat.threat + "|" + (.count.value|tostring) + "|" + (.first.value|tostring) + "|" + (.last.value|tostring) + "|" + .latest.hits.hits[0]._source.kind + "|" + (.latest.hits.hits[0]._source.score|tostring) + "|" + (.latest.hits.hits[0]._source.muted|tostring) + "|" + (.latest.hits.hits[0]._source.blocked|tostring) + "|" + (.latest.hits.hits[0]._source.country) + "|" + (.latest.hits.hits[0]._source.location)' > ${OUT}

echo "$(date +%Y-%m-%d_%H:%M:%S) - Done threats" >> ${LOG}
