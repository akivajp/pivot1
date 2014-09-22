#!/bin/bash

#THREADS=10
THREADS=4
IGNORE="1e-2"

dir=$(cd $(dirname $0); pwd)

usage()
{
  echo "usage: $0 task1 task2 work_dir"
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

trans1=${task1#*_}
trans2=${task2#*_}

show_exec mkdir -p ${workdir}
show_exec ${dir}/convert2sqlite.py ${task1}/TM/model/phrase-table.gz ${workdir}/phrase-tables.db phrase1
show_exec ${dir}/convert2sqlite.py ${task2}/TM/model/phrase-table.gz ${workdir}/phrase-tables.db phrase2
show_exec ${dir}/triangulate.py ${workdir}/phrase-tables.db phrase1 phrase2 ${workdir}/pivot.db phrase --cores ${THREADS} --ignore ${IGNORE}
show_exec ${dir}/extract.py ${workdir}/pivot.db phrase ${workdir}/phrase-table.gz

