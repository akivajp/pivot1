#!/bin/bash

MOSES=$HOME/exp/moses
TRAVATAR=$HOME/exp/travatar
BIN=$HOME/usr/local/bin
dir=$(cd $(dirname $0); pwd)

#THREADS=10
THREADS=4
FORMAT="penn"

usage()
{
  echo "usage: $0 task path/to/travatar.ini input ref [test_name]"
  echo ""
  echo "options:"
  echo "  --format={penn,egret,word}"
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

if [ ${opt_format} ]; then
  FORMAT=${opt_format}
fi

task=${ARGS[0]}
travatar_ini=${ARGS[1]}
input=${ARGS[2]}
ref=${ARGS[3]}
test_name=${ARGS[4]}

workdir="${task}/working"

show_exec mkdir -p ${workdir}
#show_exec ${TRAVATAR}/script/train/filter-model.pl ${travatar_ini} ${workdir}/filtered-test.ini ${workdir}/filtered-test \"${TRAVATAR}/script/train/filter-rt.pl -src ${input} -src-format ${FORMAT}\"
show_exec ${TRAVATAR}/script/train/filter-model.pl ${travatar_ini} ${workdir}/filtered-test.ini ${workdir}/filtered-test \"${TRAVATAR}/script/train/filter-rule-table.py ${input}\"
if [ "${test_name}" ]; then
  output=${workdir}/translated-${test_name}.out
  score=${workdir}/score-${test_name}.out
  show_exec ${BIN}/travatar -config_file ${workdir}/filtered-test.ini -threads ${THREADS} \< ${input} \> ${output}
  show_exec ${BIN}/mt-evaluator -ref ${ref} ${output} \> ${score}
  head ${score}
else
  show_exec ${BIN}/travatar -config_file ${workdir}/filtered-test.ini -threads ${THREADS} \< ${input} \> ${workdir}/translated.out
  show_exec ${BIN}/mt-evaluator -ref ${ref} ${workdir}/translated.out
fi
show_exec rm -rf ${workdir}/filtered-test

