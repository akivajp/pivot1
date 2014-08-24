#!/bin/bash

MOSES=/home/is/akiba-mi/exp/moses

dir=$(cd $(dirname $0); pwd)

usage()
{
  echo "usage: $0 corpus1 corpus2 path/to/moses.ini task_dir"
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

if [ ${#ARGS[@]} -lt 4 ]
then
  usage
  exit 1
fi

src1=${ARGS[0]}
src2=${ARGS[1]}
moses_ini=${ARGS[2]}
task=${ARGS[3]}

workdir="${task}/working"
show_exec mkdir -p ${workdir}
show_exec cd ${workdir}
show_exec $MOSES/scripts/training/mert-moses.pl ${src1} ${src2} $MOSES/bin/moses ${moses_ini} --mertdir $MOSES/bin \> mert.out

