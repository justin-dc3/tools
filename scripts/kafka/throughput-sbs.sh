#!/bin/bash

KAFKA_HOME="/opt/kafka_2.12-2.2.1"
KAFKA_BOOTSTRAP_SERVER=" b-1.calops-pipeline.ku65zi.c4.kafka.us-east-2.amazonaws.com:9092,b-4.calops-pipeline.ku65zi.c4.kafka.us-east-2.amazonaws.com:9092,b-2.calops-pipeline.ku65zi.c4.kafka.us-east-2.amazonaws.com:9092"
export PATH=$PATH:$KAFKA_HOME/bin

NO_CLEAR=""
NO_HEADER=""
NO_REPEAR_HEADER=""
let HEADER_REPEAT_LINES=20
LOG_FILE=""
GROUP1=""
GROUP2=""
TOPIC1=""
TOPIC2=""
HELP=""
DEBUG=""
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
            group1)
               GROUP1="${!OPTIND}"
               OPTIND=$(( ${OPTIND} + 1 ))
               ;;
            group1=*)
               GROUP1="${OPTARG#*=}"
               ;;
            group2)
               GROUP2="${!OPTIND}"
               OPTIND=$(( ${OPTIND} + 1 ))
               ;;
            group2=*)
               GROUP2="${OPTARG#*=}"
               ;;
            topic1)
               TOPIC1="${!OPTIND}"
               OPTIND=$(( ${OPTIND} + 1 ))
               ;;
            topic1=*)
               TOPIC1="${OPTARG#*=}"
               ;;
            topic2)
               TOPIC2="${!OPTIND}"
               OPTIND=$(( ${OPTIND} + 1 ))
               ;;
            topic2=*)
               TOPIC2="${OPTARG#*=}"
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
            debug)
               DEBUG="true"
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
     log $'TS\t\t\tIN\tOUT\tTP\tDUR\tIN/s\tOUT/s\tTP/s\tP\tC\tSTATUS\tLAG\tGROUP\tTOPIC'
  _header="1"
}

debug() {
  log "Group1: ${GROUP1}; Topic1: ${TOPIC1}"
  log "Group2: ${GROUP2}; Topic2: ${TOPIC2}"
  log "CMD1: ${_cmd1}"
  log "CMD2: ${_cmd2}"
  log "TEMP2: $(cat ${_temp2})"
  log "TS2: ${_ts2}"
  log "TEMP4: $(cat ${_temp4})"
  log "TS4: ${_ts4}"
  fin
}

init() {
  (( _run=0 ))
  _temp2=$(mktemp)
  _temp4=$(mktemp)
  eval ${_cmd1} > ${_temp2} && _ts2=$(date +%Y%m%d%H%M%S)
  eval ${_cmd2} > ${_temp4} && _ts4=$(date +%Y%m%d%H%M%S)
  [ -z "${NO_CLEAR}" ] && clear
  [ -z "${NO_HEADER}" ] && header
  [ -z "${DEBUG}" ] || debug
}

fin() {
  rm -rf ${_temp1} ${_temp2}
  exec 9>&-
  exit
}


usage() {
  echo "Usage: $(basename $0) --group1 <group> [--topic1 <topic>] --group2 <group> [--topic2 <topic>] [--no-clear] [--no-header|--no-repeat-header|--header-repeat-lines <lines>] [--log_dir <dir>|--quiet]" && fin
}

log() {
   echo "$(date +%Y-%m-%dT%H:%M:%S.%N%z) - $@" >&9
}

report() {
  local _group=${group}
  local _topic=${topic}
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
  log "$_ts"$'\t'"$_in"$'\t'"$_out"$'\t'"$_tp"$'\t'"$_secs"$'\t'"$_in_rate"$'\t'"$_out_rate"$'\t'"$_tp_sign$_tp_rate"$'\t'"$_part"$'\t'"$_cons"$'\t'"$_status"$'\t'"${_lag}"$'\t'"${_group}"$'\t'"${_topic}"
}

[ -z "${HELP}" ] || usage
[ -z "${LOG_FILE}" ] && exec 9>&1 || exec 9>${LOG_FILE}
[ -z "${GROUP1}" ] && usage
[ -z "${GROUP2}" ] && usage
[ -z "${TOPIC1}" ] && TOPIC1="${GROUP1}Stream"
[ -z "${TOPIC2}" ] && TOPIC2="${GROUP2}Stream"

_cmd1="kafka-consumer-groups.sh --bootstrap-server ${KAFKA_BOOTSTRAP_SERVER} --describe --group ${GROUP1} 2>/dev/null | grep ${TOPIC1} | sort -k2 -n" && echo "${_cmd1}"
_cmd2="kafka-consumer-groups.sh --bootstrap-server ${KAFKA_BOOTSTRAP_SERVER} --describe --group ${GROUP2} 2>/dev/null | grep ${TOPIC2} | sort -k2 -n" && echo "${_cmd2}"
_temp2=""
_temp4=""
_ts2=""
_ts4=""
_header=""
group=""
topic=""
declare -i _run tsdiff rate_in rate_out count consumers lag
init
exit


while (true); do
  rm -rf ${_temp1} ${_temp3}
  _temp1=${_temp2}
  _temp2=$(mktemp)
  _temp3=${_temp4}
  _temp4=$(mktemp)
  _ts1=$_ts2
  _ts3=$_ts4
  eval ${_cmd1} > ${_temp2} && _ts2=$(date +%Y%m%d%H%M%S)
  eval ${_cmd2} > ${_temp4} && _ts4=$(date +%Y%m%d%H%M%S)
  group="${GROUP1}"
  topic="${TOPIC1}"
  (( tsdiff=$_ts2-$_ts1 ))
  old_current1=($(cat ${_temp1} | awk '{print$3}')) && old_log1=($(cat ${_temp1} | awk '{print$4}')) && consumers1=$(cat ${_temp1} | awk '{print$6}' | sort -u | wc -l)
  new_current1=($(cat ${_temp2} | awk '{print$3}')) && new_log1=($(cat ${_temp2} | awk '{print$4}')) && new_lag1=($(cat ${_temp2} | awk '{print$5}'))
  let count=${#old_current1[@]}
  let part=0
  let rate_in=0
  let rate_out=0
  let lag=0
  while [[ $part -lt $count ]]; do
    (( rate_out=rate_out+new_current1[part]-old_current1[part] )) 
    (( rate_in=rate_in+new_log1[part]-old_log1[part] ))
    (( lag=lag+new_lag1[part] ))
    (( part++ ))
  done
  (( _run++ )) && report
  group="${GROUP2}"
  topic="${TOPIC2}"
  (( tsdiff=$_ts4-$_ts3 ))
  old_current2=($(cat ${_temp3} | awk '{print$3}')) && old_log2=($(cat ${_temp3} | awk '{print$4}')) && consumers2=$(cat ${_temp3} | awk '{print$6}' | sort -u | wc -l)
  new_current2=($(cat ${_temp4} | awk '{print$3}')) && new_log2=($(cat ${_temp4} | awk '{print$4}')) && new_lag2=($(cat ${_temp4} | awk '{print$5}'))
  let count=${#old_current2[@]}
  let part=0
  let rate_in=0
  let rate_out=0
  let lag=0
  while [[ $part -lt $count ]]; do
    (( rate_out=rate_out+new_current2[part]-old_current2[part] )) 
    (( rate_in=rate_in+new_log2[part]-old_log2[part] ))
    (( lag=lag+new_lag2[part] ))
    (( part++ ))
  done
  (( _run++ )) && report
  sleep 5
done

fin
