#!/bin/bash

UUID=$1 && [ -z "${UUID}" ] && echo "Must provide UUID." && exit
SENSOR=$(psql -h saas-db-coordinator-1.darkcubed.calops -U dark3 -d dark3 -A -t -c "SELECT sensor_uuid FROM collections.sensors WHERE sensor_uuid = '${UUID}' OR account_uuid = '${UUID}' LIMIT 1;") && [ -z "${SENSOR}" ] && echo "Invalid UUID" && exit
LOG="${SENSOR}.log"
SENSOR_COMPACT=$(echo "${SENSOR}" | tr -d '-')

sudo -u postgres psql -d reporting -c "CREATE TABLE reporting.no_scores_${SENSOR_COMPACT} (sensor_uuid uuid, threat_address varchar, threat_score int, CONSTRAINT pk_no_scores_${SENSOR_COMPACT} PRIMARY KEY (sensor_uuid, threat_address));" >> ${LOG} 2>&1
sudo -u postgres psql -d reporting -c "CREATE INDEX idx_no_scores_${SENSOR_COMPACT}_threat_address ON reporting.no_scores_${SENSOR_COMPACT} (threat_address);" >> ${LOG} 2>&1
sudo -u postgres psql -d reporting -c "INSERT INTO reporting.no_scores_${SENSOR_COMPACT} (sensor_uuid, threat_address, threat_score) WITH threats AS (SELECT DISTINCT sensor_uuid, threat_address, threat_score FROM reporting.sensor_threat_details_${SENSOR_COMPACT} WHERE threat_score = 0), traffic AS (SELECT DISTINCT sensor_uuid, threat_address, threat_score FROM reporting.sensor_traffic_details_${SENSOR_COMPACT} WHERE threat_score = 0) SELECT sensor_uuid, threat_address, threat_score FROM threats UNION SELECT sensor_uuid, threat_address, threat_score FROM traffic;" >> ${LOG} 2>&1

for t in $(sudo -u postgres psql -d reporting -A -t -c "SELECT DISTINCT threat_address FROM reporting.no_scores_${SENSOR_COMPACT} WHERE threat_score = 0;"); do
   s=$(redis-cli -c -h saas-redis.jqj9j7.clustercfg.use2.cache.amazonaws.com hget "score|$t" current | tr -d '"')
   echo -n "Threat: $t; Score: $s ..." >> ${LOG}
   [ ! -z "${s}" ] && sudo -u postgres psql -d reporting -c "UPDATE reporting.no_scores_${SENSOR_COMPACT} SET threat_score = $s WHERE threat_address = '$t';" >> ${LOG} 2>&1
done

sudo -u postgres psql -d reporting -c "UPDATE reporting.sensor_threat_details_${SENSOR_COMPACT} std SET threat_score = (SELECT threat_score FROM reporting.no_scores_${SENSOR_COMPACT} ns WHERE ns.sensor_uuid = std.sensor_uuid AND ns.threat_address = std.threat_address) WHERE threat_score = 0;" >> ${LOG} 2>&1
sudo -u postgres psql -d reporting -c "UPDATE reporting.sensor_traffic_details_${SENSOR_COMPACT} std SET threat_score = (SELECT threat_score FROM reporting.no_scores_${SENSOR_COMPACT} ns WHERE ns.sensor_uuid = std.sensor_uuid AND ns.threat_address = std.threat_address) WHERE threat_score = 0;" >> ${LOG} 2>&1

