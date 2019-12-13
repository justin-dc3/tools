#!/bin/bash

NO_CLEAR=""
NO_HEADER=""
NO_REPEAR_HEADER=""
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
  echo $'Node Resource Details\tDeployment: '"${_dep}"
  echo $'ALERT\t\tNS\t\tPOD\t\t\t\t\tSTATE\tIP\t\tNODE\t\t\t\t\t\tCPU\tMEM'
}

init() {
  _temp1=$(mktemp)
  _temp2=$(mktemp)
  _temp3=$(mktemp)
  [ -z "${NO_CLEAR}" ] && clear
  [ -z "${NO_HEADER}" ] && header
}

fin() {
  rm -rf ${_temp1} ${_temp2} ${_temp3}
  exit
}

usage() {
  echo "Usage: $(basename $0) [--no-clear] [--no-header|--no-repeat-header] <deployment>" && fin
}

report() {
  local _i=$1
  echo "${alert[$_i]}"$'\t'"${ns[$_i]}"$'\t'"${pod[$_i]}"$'\t'"${state[$_i]}"$'\t'"${ip[$_i]}"$'\t'"${node[$_i]}"$'\t'"${nodecpu[$_i]}"$'\t'"${nodemem[$_i]}"
}

[ -z "${HELP}" ] || usage
_dep=$1
[ -z "${_dep}" ] && usage
_temp1=""
_temp2=""
_temp3=""

init

_cmd1="kubectl get pods --all-namespaces -o wide | grep ${_dep}"
_cmd2="kubectl top nodes | tail +2"

eval ${_cmd1} > ${_temp1} && eval ${_cmd2} > ${_temp2}
nodes=($(cat ${_temp1} | awk '{print$8}' | sort -u))
for n in ${nodes[@]}; do top="$(grep ${n} ${_temp2})"; sed -i "s/${n}/${top}/g" ${_temp1}; done
cat ${_temp1} | sort -k10 -n -r > ${_temp3}
declare -A alert
ns=($(cat ${_temp3} | awk '{print$1}'))
pod=($(cat ${_temp3} | awk '{print$2}'))
state=($(cat ${_temp3} | awk '{print$4}'))
mins=($(cat ${_temp3} | awk '{print$6}'))
ip=($(cat ${_temp3} | awk '{print$7}'))
node=($(cat ${_temp3} | awk '{print$8}'))
nodecpu=($(cat ${_temp3} | awk '{print$10}'))
nodemem=($(cat ${_temp3} | awk '{print$12}'))
let i=0
while [[ $i -lt ${#ns[@]} ]]; do
  alert[$i]=$'\t'
  critical=""
  warning=""
  [[ ${state[$i]} != "Running" ]] && warning="y"
  cpu=$(echo ${nodecpu[$i]} | tr -d '%')
  [[ $cpu -gt 95 ]] && critical="y"
  [[ $cpu -gt 85 ]] && warning="y"
  mem=$(echo ${nodemem[$i]} | tr -d '%')
  [[ $mem -gt 90 ]] && critical="y"
  [[ $mem -gt 80 ]] && warning="y"
  [[ $warning = "y" ]] && alert[$i]="WARNING "
  [[ $critical = "y" ]] && alert[$i]="CRITICAL"
  report $i
  (( i++ ))
done


fin

