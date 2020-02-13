#!/bin/bash

UUID=$1 && [ -z "${UUID}" ] && echo "Must provide UUID." && exit
SENSOR=$(psql -h saas-db-coordinator-1.darkcubed.calops -U dark3 -d dark3 -A -t -c "SELECT sensor_uuid FROM collections.sensors WHERE sensor_uuid = '${UUID}' OR account_uuid = '${UUID}' LIMIT 1;") && [ -z "${SENSOR}" ] && echo "Invalid UUID" && exit
LOG="${SENSOR}.log"
QUERY="stage.sql"
SENSOR_COMPACT=$(echo "${SENSOR}" | tr -d '-')
SQL=$(cat ${QUERY} | sed -e "s/SENSOR_COMPACT/${SENSOR_COMPACT}/g" | sed -e "s/SENSOR/${SENSOR}/g")

sudo -u postgres psql -d reporting -c "${SQL}" >> ${LOG} 2>&1

recv=$(sudo -u postgres psql -d reporting -A -t -c "SELECT count(*) FROM reporting.stage_traffic_${SENSOR_COMPACT} WHERE received_bytes > 0;" | awk '{print $1}')
if [[ $recv -eq 0 ]]; then
   echo "Need to massage data" >> ${LOG}
fi
