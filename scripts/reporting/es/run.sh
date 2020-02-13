#!/bin/bash

UUID=$1 && [ -z "${UUID}" ] && echo "Must provide uuid" && exit
SENSOR=$(sudo -u postgres psql -h saas-db-coordinator-1.darkcubed.calops -U dark3 -d dark3 -A -t -c "SELECT sensor_uuid FROM collections.sensors WHERE sensor_uuid = '${UUID}' OR account_uuid = '${UUID}' LIMIT 1;") && [ -z "${SENSOR}" ] && echo "Invalid uuid" && exit
LOG="${SENSOR}.log" && cat /dev/null > ${LOG}

bash traffic.sh ${SENSOR} && \
bash threats.sh ${SENSOR} && \
bash stage.sh ${SENSOR} && \
bash load.sh ${SENSOR} && \
tar cfz archive/${SENSOR}.tgz *${SENSOR}.* && rm -rf *${SENSOR}.*
