#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
stamp=$(date +"%Y/%m/%d %H:%M:%S")

source ${dir}/config.sh

get_stamp()
{
  local FILE=$1
  local PANE=""
  local TSTAMP=$(date +"%Y/%m/%d %H:%M:%S")
  local H=${HOST}
  if [ "${HOSTNAME}" ]; then
    H=${HOSTNAME}
  fi
  local TPANE=$(tmux display -p "#I.#P" 2> /dev/null)
  if [ "${TMUX_PANE}" ]; then
    PANE=":${TPANE}"
  fi
  echo "${TSTAMP} on ${H}${TPANE}"
}
export -f get_stamp

show_exec()
{
  local STAMP=$(get_stamp)
  echo "[exec ${STAMP}] $*" | tee -a ${LOG}
  eval $*

  if [ $? -gt 0 ]
  then
    local red=31
    local msg="[error ${STAMP}]: $*"
    echo -e "\033[${red}m${msg}\033[m" | tee -a ${LOG}
    exit 1
  fi
}
export -f show_exec

proc_args()
{
  ARGS=()
  OPTS=()

  while [ $# -gt 0 ]
  do
    arg=$1
    case $arg in
      --*=* )
        opt=${arg#--}
        name=${opt%=*}
        var=${opt#*=}
        eval "opt_${name}=${var}"
        ;;
      --* )
        name=${arg#--}
        eval "opt_${name}=1"
        ;;
      -* )
        OPTS+=($arg)
        ;;
      * )
        ARGS+=($arg)
        ;;
    esac

    shift
  done
}
export -f proc_args

abspath()
{
  ABSPATHS=()
  for path in "$@"; do
    ABSPATHS+=(`echo $(cd $(dirname $path) && pwd)/$(basename $path)`)
  done
  echo "${ABSPATHS[@]}"
}
export -f abspath

ask_continue()
{
  local testfile=$1
  local REP=""
  if [ "${testfile}" ]; then
    if [ ! -e ${testfile} ]; then
      return
    else
      echo -n "\"${testfile}\" is found. do you want to continue? [y/n]: "
    fi
  else
    echo -n "do you want to continue? [y/n]: "
  fi
  while [ 1 ]; do
    read REP
    case $REP in
      y*|Y*) break ;;
      n*|N*) exit ;;
      *) echo -n "type y or n: " ;;
    esac
  done
}
export -f ask_continue

proc_args $*

if [ "${opt_method}" ]; then
  METHOD="${opt_method}"
fi

if [ "${opt_lexmethod}" ]; then
  LEX_METHOD="${opt_lexmethod}"
elif [ "${opt_lex_method}" ]; then
  LEX_METHOD="${opt_lex_method}"
elif [ "${opt_lmethod}" ]; then
  LEX_METHOD="${opt_lmethod}"
fi

if [ "${opt_jointmethod}" ]; then
  JOINT_METHOD="${opt_jointmethod}"
elif [ "${opt_joint_method}" ]; then
  JOINT_METHOD="${opt_joint_method}"
elif [ "${opt_jmethod}" ]; then
  JOINT_METHOD="${opt_jmethod}"
fi

if [ $opt_threads ]; then
  THREADS=${opt_threads}
fi

get_mt_method()
{
  local taskname=$1
  local mt_method=$(expr $taskname : '.*_\(.*\)_..-')
  if [ ! "${mt_method}" ]; then
    mt_method=$(expr $taskname : '\(.*\)_..-')
  fi
  echo ${mt_method}
}

get_lang_src()
{
  local taskname=$1
  expr ${taskname} : '.*_\(..\)-'
}

get_lang_trg()
{
  local taskname=$1
  local lang=$(expr $taskname : '.*_..-..-\(..\)')
  if [ ! "${lang}" ]; then
    lang=$(expr $taskname : '.*_..-\(..\)')
  fi
  echo ${lang}
}

solve_decoder()
{
  local mt_method=$1
  case ${mt_method} in
    pbmt)
      decoder=moses
      ;;
    hiero)
      decoder=travatar
      ;;
    t2s)
      decoder=travatar
      ;;
    *)
      echo "mt_methos should be one of pbmt/hiero/t2s"
      exit 1
      ;;
  esac
}

