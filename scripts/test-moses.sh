#!/bin/bash

MOSES=$HOME/exp/moses
dir=$(cd $(dirname $0); pwd)
THREADS=4

usage()
{
  echo "usage: $0 task path/to/moses.ini"
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

if [ ${#ARGS[@]} -lt 2 ]
then
  usage
  exit 1
fi

task=${ARGS[0]}
moses_ini=${ARGS[1]}

trans=${task#./}
trans=${trans%/}
trans=${trans#*_}
lang1=${trans%-*}
lang2=${trans#*-}

workdir="${task}/working"
corpus="${task}/corpus"

show_exec mkdir -p ${workdir}
show_exec ${MOSES}/bin/moses -f ${moses_ini} -threads ${THREADS} \< ${corpus}/test.true.${lang1} \> ${workdir}/translated.out
show_exec ${MOSES}/scripts/generic/multi-bleu.perl -lc ${corpus}/test.true.${lang2} \< ${workdir}/translated.out
