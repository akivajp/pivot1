#!/bin/bash

TRAVATAR=$HOME/exp/travatar

dir=$(cd $(dirname $0); pwd)

NBEST=200
THREADS=10
FORMAT="penn"

usage()
{
  echo "usage: $0 corpus1 corpus2 path/to/travatar.ini task_dir"
  echo ""
  echo "options:"
  echo "  --threads={integer}"
  echo "  --format={penn,egret,word}"
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

if [ ${opt_threads} ]; then
  THREADS=${opt_threads}
fi

if [ ${opt_format} ]; then
  FORMAT=${opt_format}
fi

src1=${ARGS[0]}
src2=${ARGS[1]}
moses_ini=${ARGS[2]}
task=${ARGS[3]}

workdir="${task}/working"
show_exec mkdir -p ${workdir}
#show_exec cd ${workdir}
#show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${moses_ini} -nbest ${NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} --working-dir ${workdir}/mert-work -threads ${THREADS} -eval bleu \> ${task}/tune.log
show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${moses_ini} -nbest ${NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} --working-dir ${workdir}/mert-work -in-format ${FORMAT} -threads ${THREADS} -eval bleu \> ${task}/tune.log

