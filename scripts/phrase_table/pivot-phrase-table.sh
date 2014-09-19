#!/bin/bash

#THREADS=10
THREADS=4

dir=$(cd $(dirname $0); pwd)

echo "running script $0 with PID: $$"

usage()
{
  echo "usage: $0 task1 task2 work_dir"
  echo ""
  echo "options:"
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

proc_args $*

if [ ${#ARGS[@]} -lt 3 ]
then
  usage
  exit 1
fi

task1=${ARGS[0]}
task2=${ARGS[1]}
workdir=${ARGS[2]}

show_exec mkdir -p ${workdir}
show_exec ${dir}/convert2sqlite.py ${task1}/TM/model/phrase-table.gz ${workdir}/phrase-table.db phrase1
show_exec ${dir}/convert2sqlite.py ${task2}/TM/model/phrase-table.gz ${workdir}/phrase-table.db phrase2

