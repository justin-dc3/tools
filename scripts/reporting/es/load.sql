CREATE TABLE reporting.sensor_threat_details_SENSOR_COMPACT (
  sensor_uuid uuid NOT NULL,
  threat_address varchar(250) NOT NULL,
  threat_count bigint,
  first_seen timestamptz,
  last_seen timestamptz,
  address_type_code varchar(10),
  threat_score int,
  muted boolean,
  blocked boolean,
  country_code varchar(10),
  latitude numeric,
  longitude numeric,
  CONSTRAINT pk_sensor_threat_details_SENSOR_COMPACT PRIMARY KEY (sensor_uuid, threat_address)
)
;
CREATE INDEX idx_sensor_threat_details_SENSOR_COMPACT_threat_address ON reporting.sensor_threat_details_SENSOR_COMPACT (threat_address);

INSERT INTO reporting.sensor_threat_details_SENSOR_COMPACT 
SELECT sensor_uuid, threat_address, threat_count, first_seen, last_seen, threat_type, threat_score, muted, blocked, country_code, latitude, longitude
FROM reporting.stage_threats_SENSOR_COMPACT;

DROP TABLE reporting.stage_threats_SENSOR_COMPACT;

CREATE TABLE reporting.sensor_traffic_details_SENSOR_COMPACT (
  sensor_uuid uuid NOT NULL,
  source_address varchar(250) NOT NULL,
  dest_address varchar(250) NOT NULL,
  protocol_name varchar(50) NOT NULL,
  dest_port_value int NOT NULL,
  threat_address varchar(250),
  internal_ip_address inet,
  originated varchar(20),
  connection_count bigint,
  first_seen timestamptz,
  last_seen timestamptz,
  sent_data_bytes bigint,
  received_data_bytes bigint,
  threat_score int,
  country text,
  latitude numeric,
  longitude numeric,
  CONSTRAINT pk_sensor_traffic_details_SENSOR_COMPACT PRIMARY KEY (sensor_uuid, source_address, dest_address, protocol_name, dest_port_value)
)
;
CREATE INDEX idx_sensor_traffic_details_SENSOR_COMPACT_threat_address ON reporting.sensor_traffic_details_SENSOR_COMPACT (threat_address);

INSERT INTO reporting.sensor_traffic_details_SENSOR_COMPACT
SELECT DISTINCT ON (sensor_uuid, source_address, dest_address, protocol_name, connection_port)
sensor_uuid, source_address, dest_address, protocol_name, connection_port, threat_address, internal_address::inet, originating, sum(connection_count) OVER w, min(first_seen) OVER w, max(last_seen) OVER w, sum(sent_bytes) OVER w, sum(received_bytes) OVER w, threat_score, country_code, latitude, longitude
FROM reporting.stage_traffic_SENSOR_COMPACT
WINDOW w AS (PARTITION BY sensor_uuid, source_address, dest_address, protocol_name, connection_port)
ORDER BY sensor_uuid, source_address, dest_address, protocol_name, connection_port, last_seen DESC;

DROP TABLE reporting.stage_traffic_SENSOR_COMPACT;
