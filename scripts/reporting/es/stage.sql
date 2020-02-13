CREATE FOREIGN TABLE reporting.ext_threats_SENSOR_COMPACT (
sensor_uuid text,
threat text,
count bigint,
first bigint,
last bigint,
type text,
score int,
muted boolean,
blocked boolean,
country text,
location text
) SERVER esdata 
OPTIONS (filename '/home/ubuntu/es/threats_SENSOR.txt', delimiter '|');

CREATE TABLE reporting.stage_threats_SENSOR_COMPACT AS
SELECT
sensor_uuid::uuid AS sensor_uuid,
threat::varchar AS threat_address,
count AS threat_count,
to_timestamp(first/1000) AS first_seen,
to_timestamp(last/1000) AS last_seen,
type::varchar AS threat_type,
score AS threat_score,
muted,
blocked,
NULLIF(country,'')::varchar AS country_code,
NULLIF(split_part(location,',',1),'')::numeric AS latitude,
NULLIF(split_part(location,',',2),'')::numeric AS longitude
FROM reporting.ext_threats_SENSOR_COMPACT;

ALTER TABLE reporting.stage_threats_SENSOR_COMPACT ADD PRIMARY KEY (sensor_uuid, threat_address);
CREATE INDEX idx_stage_threats_SENSOR_COMPACT_threat_address ON reporting.stage_threats_SENSOR_COMPACT (threat_address);
DROP FOREIGN TABLE reporting.ext_threats_SENSOR_COMPACT;

CREATE FOREIGN TABLE reporting.ext_traffic_SENSOR_COMPACT (
sensor_uuid text,
source text,
dest text,
protocol text,
sport int,
dport int,
count bigint,
first bigint,
last bigint,
sent bigint,
received bigint,
score int,
country text,
location text 
) SERVER esdata 
OPTIONS (filename '/home/ubuntu/es/traffic_SENSOR.txt', delimiter '|');

CREATE TABLE reporting.stage_traffic_SENSOR_COMPACT AS 
SELECT
sensor_uuid::uuid AS sensor_uuid,
source::varchar AS source_address,
dest::varchar AS dest_address,
NULL::varchar AS threat_address,
NULL::varchar AS internal_address,
NULL::varchar AS originating,
protocol::varchar AS protocol_name,
sport AS source_port,
dport AS dest_port,
0 AS connection_port,
count AS connection_count,
to_timestamp(first/1000) AS first_seen,
to_timestamp(last/1000) AS last_seen,
sent AS sent_bytes,
received AS received_bytes,
score AS threat_score,
NULLIF(country,'')::varchar AS country_code,
NULLIF(split_part(location,',',1),'')::numeric AS latitude,
NULLIF(split_part(location,',',2),'')::numeric AS longitude
FROM reporting.ext_traffic_SENSOR_COMPACT;

ALTER TABLE reporting.stage_traffic_SENSOR_COMPACT ADD PRIMARY KEY (sensor_uuid, source_address, dest_address, protocol_name, source_port, dest_port);
CREATE INDEX idx_stage_traffic_SENSOR_COMPACT_source_address ON reporting.stage_traffic_SENSOR_COMPACT (source_address);
CREATE INDEX idx_stage_traffic_SENSOR_COMPACT_dest_address ON reporting.stage_traffic_SENSOR_COMPACT (dest_address);
DROP FOREIGN TABLE reporting.ext_traffic_SENSOR_COMPACT;

UPDATE reporting.stage_traffic_SENSOR_COMPACT
SET threat_address = source_address, internal_address = dest_address, originating = 'EXTERNALLY', connection_port = source_port, received_bytes = sent_bytes, sent_bytes = received_bytes WHERE source_address IN (
SELECT threat_address FROM reporting.stage_threats_SENSOR_COMPACT);
UPDATE reporting.stage_traffic_SENSOR_COMPACT
SET threat_address = dest_address, internal_address = source_address, originating = 'INTERNALLY', connection_port = dest_port WHERE dest_address IN (
SELECT threat_address FROM reporting.stage_threats_SENSOR_COMPACT)
AND threat_address IS NULL;
