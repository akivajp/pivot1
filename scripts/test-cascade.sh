#!/bin/bash

MOSES=$HOME/exp/moses
TRAVATAR=$HOME/exp/travatar
BIN=$HOME/usr/local/bin
dir=$(cd $(dirname $0); pwd)

#THREADS=10
THREADS=4

usage()
{
  echo "usage: $0 task1 task2 text ref"
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

task1=${ARGS[0]}
task2=${ARGS[1]}
text=${ARGS[2]}
ref=${ARGS[3]}
method1=${task1%_*}
method2=${task2%_*}
lang1=$(expr $task1 : ".*_\(..\)" )
lang2=$(expr $task1 : ".*_..-\(..\)" )
lang3=$(expr $task2 : ".*_..-\(..\)" )

ini1=${task1}/binmodel/moses.ini
ini2=${task2}/binmodel/moses.ini
if [ "$method1" == "hiero" ]; then
  ini1=${task1}/working/mert-work/travatar.ini
fi
if [ "$method2" == "hiero" ]; then
  ini2=${task2}/working/mert-work/travatar.ini
fi

echo METHOD1: $method1
echo METHOD2: $method2
echo LANG1: $lang1
echo LANG2: $lang2
echo LANG3: $lang3
echo INI1: $ini1
echo INI2: $ini2

workdir="cascade_${method1}_${lang1}-${lang2}-${lang3}"

target1=${workdir}/translated.${lang2}
show_exec mkdir -p ${workdir}
if [ "$method1" == "moses" ]; then
  show_exec ${MOSES}/bin/moses -f ${ini1} -threads ${THREADS} \< ${text} \> ${target1}
elif [ "$method1" == "hiero" ]; then
  show_exec ${TRAVATAR}/script/train/filter-model.pl ${ini1} ${workdir}/${task1}/filtered-test.ini ${workdir}/${task1}/filtered-test \"${TRAVATAR}/script/train/filter-rt.pl -src ${text}\"
  show_exec ${BIN}/travatar -config_file ${workdir}/${task1}/filtered-test.ini -threads ${THREADS} \< ${text} \> ${target1}
fi

target2=${workdir}/translated.${lang3}
if [ "$method2" == "moses" ]; then
  show_exec ${MOSES}/bin/moses -f ${ini2} -threads ${THREADS} \< ${target1} \> ${target2}
elif [ "$method1" == "hiero" ]; then
  show_exec ${TRAVATAR}/script/train/filter-model.pl ${ini2} ${workdir}/${task2}/filtered-test.ini ${workdir}/${task2}/filtered-test \"${TRAVATAR}/script/train/filter-rt.pl -src ${target1}\"
  show_exec ${BIN}/travatar -config_file ${workdir}/${task2}/filtered-test.ini -threads ${THREADS} \< ${target1} \> ${target2}
fi

show_exec ${BIN}/mt-evaluator -ref ${ref} ${target2} \> ${workdir}/score.out

