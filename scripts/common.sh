#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
stamp=$(date +"%Y/%m/%d %H:%M:%S")

source ${dir}/config.sh

#echo "running script with PID: $$"

show_exec()
{
  echo "[exec] $*"
  eval $*

  if [ $? -gt 0 ]
  then
#    echo "[error on exec]: $*"
    local red=31
    local msg="[error on exec]: $*"
    echo -e "\033[${red}m${msg}\033[m"
    exit 1
  fi
}

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

abspath()
{
  echo $(cd $(dirname $1) && pwd)/$(basename $1)
}

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

if [ $opt_threads ]; then
  THREADS=${opt_threads}
fi

get_mt_method()
{
  local taskname=$1
  local mt_method=$(expr $taskname : '.*_\(.*\)_..-')
  if [ ! "mt_method" ]; then
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

