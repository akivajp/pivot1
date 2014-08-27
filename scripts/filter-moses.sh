#!/bin/bash

MOSES=$HOME/exp/moses
BIN=$HOME/usr/local/bin

dir=$(cd $(dirname $0); pwd)

THREADS=10

usage()
{
  echo "usage: $0 task test_input"
}

show_exec()
{
  echo "[exec] $*"
  eval $*

  if [ $? -gt 0 ]
  then
    echo "[error on exec]: $*"
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

proc_args $*

if [ ${#ARGS[@]} -lt 1 ]
then
  usage
  exit 1
fi

task=${ARGS[0]}
src=${ARGS[1]}

workdir="${task}/working"
show_exec mkdir -p ${workdir}
show_exec cd ${workdir}
show_exec ${MOSES}/scripts/training/filter-model-given-input.pl filtered mert-work/moses.ini ${src} -Binarizer ${BIN}/processPhraseTable

