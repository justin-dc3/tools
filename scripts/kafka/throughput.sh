#!/bin/bash

KAFKA_HOME="/opt/kafka_2.12-2.2.1"
KAFKA_BOOTSTRAP_SERVER=" b-1.calops-pipeline.ku65zi.c4.kafka.us-east-2.amazonaws.com:9092,b-4.calops-pipeline.ku65zi.c4.kafka.us-east-2.amazonaws.com:9092,b-2.calops-pipeline.ku65zi.c4.kafka.us-east-2.amazonaws.com:9092"
export PATH=$PATH:$KAFKA_HOME/bin

NO_CLEAR=""
NO_HEADER=""
NO_REPEAR_HEADER=""
let HEADER_REPEAT_LINES=20
LOG_FILE=""
HELP=""
OPTSPEC=":-:"
ARGS="$@"
while getopts "${OPTSPEC}" OPT; do
   case "${OPT}" in
      -)
         case "${OPTARG}" in
            no-clear)
               NO_CLEAR="true"
               ;;
            no-header)
               NO_HEADER="true"
               ;;
            no-repeat-header)
               NO_REPEAT_HEADER="true"
               ;;
            header-repeat-lines)
               let HEADER_REPEAT_LINES=${!OPTIND}
               OPTIND=$(( ${OPTIND} + 1 ))
               ;;
            header-repeat-lines=*)
               let HEADER_REPEAT_LINES=${OPTARG#*=}
               ;;
            log_dir)
               LOG_FILE="${!OPTIND}/${SCRIPT%.*}_${RUNTS}.log"
               OPTIND=$(( ${OPTIND} + 1 ))
               ;;
            log_dir=*)
               LOG_FILE="${OPTARG#*=}/${SCRIPT%.*}_${RUNTS}.log"
               ;;
            quiet)
               LOG_FILE="/dev/null"
               ;;
            help)
               HELP="true"
               ;;
         esac
         ;;
    esac
done
shift $((OPTIND-1))



header() {
  local _doit=""
  [ -z "${NO_HEADER}" ] || _doit="1"
  [ -z "$_header" ] || [ -z "${NO_REPEAT_HEADER}" ] && _doit="1"
  [ -z "$_doit" ] || \
     log $'Consumer Group:'"${_group}"$'\tTopic:'"${_topic}" && \
     log $'TS\t\t\tIN\tOUT\tTP\tDUR\tIN/s\tOUT/s\tTP/s\tP\tC\tSTATUS\tLAG'
  _header="1"
}

init() {
  (( _run=0 ))
  _temp2=$(mktemp)
  eval ${_cmd} > ${_temp2} && _ts2=$(date +%Y%m%d%H%M%S)
  [ -z "${NO_CLEAR}" ] && clear
  [ -z "${NO_HEADER}" ] && header
}

fin() {
  rm -rf ${_temp1} ${_temp2}
  exec 9>&-
  exit
}


usage() {
  echo "Usage: $(basename $0) [--no-clear] [--no-header|--no-repeat-header|--header-repeat-lines <lines>] [--log_dir <dir>|--quiet] <group> [<topic>]" && fin
}

log() {
   echo "$(date +%Y-%m-%dT%H:%M:%S.%N%z) - $@" >&9
}

report() {
  local _secs=${tsdiff}
  local _in=${rate_in}
  local _out=${rate_out}
  local _part=${count}
  local _cons=${consumers}
  local _lag=${lag}
  local _ts=$(date +%Y%m%d%H%M%S)
  local _break
  local _in_rate
  local _out_rate
  local _tp
  local _tp_rate
  local _status
  local _tp_sign
  _break=$(( $_run%$HEADER_REPEAT_LINES )) && [[ $_break -eq 0 ]] && header
  (( _in_rate=_in/_secs ))
  (( _out_rate=_out/_secs ))
  if [[ $_in -gt $_out ]]; then
    (( _tp=_in-_out )) && (( _tp_rate=_tp/_secs )) && _status="BAD" && _tp_sign="-"
  else
    (( _tp=_out-_in )) && (( _tp_rate=_tp/_secs )) && _status="GOOD" && _tp_sign=""
  fi
  log "$_ts"$'\t'"$_in"$'\t'"$_out"$'\t'"$_tp"$'\t'"$_secs"$'\t'"$_in_rate"$'\t'"$_out_rate"$'\t'"$_tp_sign$_tp_rate"$'\t'"$_part"$'\t'"$_cons"$'\t'"$_status"$'\t'"${_lag}"
}

[ -z "${HELP}" ] || usage
[ -z "${LOG_FILE}" ] && exec 9>&1 || exec 9>${LOG_FILE}
_group="$1"
[ -z "${_group}" ] && usage
_topic="$2"
[ -z "${_topic}" ] && _topic="${_group}Stream"

_cmd="kafka-consumer-groups.sh --bootstrap-server ${KAFKA_BOOTSTRAP_SERVER} --describe --group ${_group} 2>/dev/null | grep ${_topic} | sort -k2 -n"
_temp2=""
_ts2=""
_header=""
declare -i _run
init

while (true); do
  rm -rf ${_temp1}
  _temp1=${_temp2}
  _temp2=$(mktemp)
  _ts1=$_ts2
  eval ${_cmd} > ${_temp2} && _ts2=$(date +%Y%m%d%H%M%S)
  (( tsdiff=$_ts2-$_ts1 ))
  old_current=($(cat ${_temp1} | awk '{print$3}')) && old_log=($(cat ${_temp1} | awk '{print$4}')) && consumers=$(cat ${_temp1} | awk '{print$6}' | sort -u | wc -l)
  new_current=($(cat ${_temp2} | awk '{print$3}')) && new_log=($(cat ${_temp2} | awk '{print$4}')) && new_lag=($(cat ${_temp2} | awk '{print$5}'))
  let count=${#old_current[@]}
  let part=0
  let rate_in=0
  let rate_out=0
  let lag=0
  while [[ $part -lt $count ]]; do
    (( rate_out=rate_out+new_current[part]-old_current[part] )) 
    (( rate_in=rate_in+new_log[part]-old_log[part] ))
    (( lag=lag+new_lag[part] ))
    (( part++ ))
  done
  (( _run++ )) && report
  sleep 5
done

fin
