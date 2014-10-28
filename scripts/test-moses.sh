#!/bin/bash

MOSES=$HOME/exp/moses
TRAVATAR=$HOME/exp/travatar
dir=$(cd $(dirname $0); pwd)
BIN=$HOME/usr/local/bin
THREADS=4

usage()
{
  echo "usage: $0 task path/to/moses.ini input ref [test_name]"
  echo ""
  echo "options:"
  echo "  --threads={integer}"
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

task=${ARGS[0]}
moses_ini=${ARGS[1]}
input=${ARGS[2]}
ref=${ARGS[3]}
test_name=${ARGS[4]}

workdir="${task}/working"

show_exec mkdir -p ${workdir}
#show_exec ${MOSES}/bin/moses -f ${moses_ini} -threads ${THREADS} \< ${corpus}/test.true.${lang1} \> ${workdir}/translated.out
if [ "${test_name}" ]; then
  output=${workdir}/translated-${test_name}.out
  score=${workdir}/score-${test_name}.out
  #show_exec ${BIN}/mt-evaluator -ref ${corpus}/test.true.${lang2} ${workdir}/translated.out \> ${output}
  show_exec ${MOSES}/bin/moses -f ${moses_ini} -threads ${THREADS} \< ${input} \> ${output}
  show_exec ${BIN}/mt-evaluator -ref ${ref} ${output} \> ${score}
else
  show_exec ${MOSES}/bin/moses -f ${moses_ini} -threads ${THREADS} \< ${input} \> ${output}
  show_exec ${BIN}/mt-evaluator -ref ${ref} ${workdir}/translated.out
fi

