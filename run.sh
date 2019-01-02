#!/bin/sh

CONFIG_FILE=${CONFIG_FILE:-"/etc/influxdb-relay/influxdb-relay.conf"}

INFLUXDB_ADDITIONAL_ARGS=${INFLUXDB_ADDITIONAL_ARGS:-""}
INFLUXDB_PROTO=${INFLUXDB_PROTO:-"http"}    # http|udp
INFLUXDB_NAME="influxdb_relay_${INFLUXDB_PROTO}"
INFLUXDB_BIND_ADDR=${INFLUXDB_BIND_ADDR:-"0.0.0.0:9086"}
INFLUXDB_MTU=${INFLUXDB_MTU:-"1024"}
INFLUXDB_BUFFER_SIZE_MB=${INFLUXDB_BUFFER_SIZE_MB:-"100"}
INFLUXDB_MAX_BATCH_KB=${INFLUXDB_MAX_BATCH_KB:-"50"}
INFLUXDB_MAX_DELAY_INTERVAL=${INFLUXDB_MAX_DELAY_INTERVAL:-"5s"}

update_conf () {

  # Print header
  awk 'BEGIN {
      printf("\n[['${INFLUXDB_PROTO}']]\nname = \"'${INFLUXDB_NAME}'\"\nbind-addr = \"'${INFLUXDB_BIND_ADDR}'\"\noutput = [\n") 
  }'

  # Build Update configfile based on ENV variables
  if [ "${INFLUXDB_PROTO}" = "http" ]
  then
    env | grep "INFLUXDB_BACKEND_.*="| sed -e "s/^INFLUXDB_BACKEND_//" | awk '{
      split($0,a,"=")
      printf("  { name=\"%s\", location=\"%s/write\", buffer-size-mb=%s, max-batch-kb=%s, max-delay-interval=\"%s\" },\n", \
        a[1], a[2], "'${INFLUXDB_BUFFER_SIZE_MB}'", "'${INFLUXDB_MAX_BATCH_KB}'", "'${INFLUXDB_MAX_DELAY_INTERVAL}'" \
      ) \
    }'
  else
    env | grep "INFLUXDB_BACKEND_.*="| sed -e "s/^INFLUXDB_BACKEND_//" | awk '{
      split($0,a,"=")
      printf("  { name=\"%s\", location = \"%s/write\", mtu=\"%s\" },\n", \
        a[1], a[2], "'${INFLUXDB_MTU}'" \
      ) \
    }'
  fi

  # Print footer
  echo "]"
}
  

# Check if INFLUXDB_BACKEND_. env config variables are found
if [ `env | grep -c "INFLUXDB_BACKEND_.*="` -le 0 ]
then
  echo "ERROR - unable to generate $CONFIG_FILE because no INFLUXDB_BACKEND_ enviroment variables were found"
  exit 1
fi

update_conf > ${CONFIG_FILE}

# ensure a config file exists
if [ ! -f "${CONFIG_FILE}" ]
then
 echo "ERROR - can't find ${CONFIG_FILE}"
 exit 1
fi

CMD="/usr/bin/influxdb-relay"
CMDARGS="-config=${CONFIG_FILE}"
exec "$CMD" $CMDARGS $INFLUXDB_ADDITIONAL_ARGS
