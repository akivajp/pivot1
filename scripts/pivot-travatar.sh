#!/bin/bash

KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod
MOSES=$HOME/exp/moses
BIN=$HOME/usr/local/bin
KYTEA=$BIN/kytea
PYTHONPATH=$HOME/exp/explib-python/lib

IRSTLM=~/exp/irstlm
GIZA=~/usr/local/bin

#THREADS=10
THREADS=4

#IGNORE="-5"
IGNORE="-7"

dir=$(cd $(dirname $0); pwd)

echo "running script with PID: $$"

usage()
{
  echo "usage: $0 task1 task2 corpus_dir"
  echo ""
  echo "options:"
  echo "  --task_name={string}"
  echo "  --threads={integer}"
#  echo "  --on_memory"
  echo "  --skip_pivot"
  echo "  --skip_tuning"
  echo "  --skip_test"
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
taskname1=$(basename $task1)
taskname2=$(basename $task2)
corpus_src=${ARGS[2]}

method=$(expr $taskname1 : '\(.*\)_..-..')
lang1=$(expr $taskname1 : '.*_\(..\)-..')
lang2=$(expr $taskname1 : '.*_..-\(..\)')
lang3=$(expr $taskname2 : '.*_..-\(..\)')

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="pivot_${method}_${lang1}-${lang2}-${lang3}"
fi

if [ $opt_threads ]; then
  THREADS=$opt_threads
fi

show_exec mkdir -p ${task}

corpus="${task}/corpus"
langdir=${task}/LM_${lang3}
workdir="${task}/working"
transdir=${task}/TM
if [ $opt_skip_pivot ]; then
  echo [skip] pivot
elif [ -f ${transdir}/model/travatar.ini ]; then
  echo [autoskip] pivot
else
  # COPYING CORPUS
  show_exec mkdir -p ${corpus}
  show_exec cp ${corpus_src}/test.true.{${lang1},${lang3}} ${corpus}
  show_exec cp ${corpus_src}/dev.true.{${lang1},${lang3}} ${corpus}
  
  # COPYING LM
  show_exec mkdir -p ${langdir}
  show_exec cp ${task2}/LM_${lang3}/train.blm.${lang3} ${langdir}
  
  # PIVOTING
  show_exec mkdir -p ${transdir}/model
  if [ $opt_on_memory ]; then
    show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/pivot.py ${task1}/TM/model/rule-table.gz ${task2}/TM/model/rule-table.gz ${transdir}/model/rule-table.gz --ignore ${IGNORE}
  else
    show_exec mkdir -p ${workdir}
    show_exec zcat ${task1}/TM/model/rule-table.gz \> ${workdir}/rule_${lang1}-${lang2}
    show_exec zcat ${task2}/TM/model/rule-table.gz \> ${workdir}/rule_${lang2}-${lang3}
    #show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/pivot.py ${task1}/TM/model/rule-table.gz ${task2}/TM/model/rule-table.gz ${transdir}/model/rule-table.gz --ignore ${IGNORE} --dbfile ${workdir}/rule.db
    show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/triangulate.py ${workdir}/rule_${lang1}-${lang2} ${workdir}/rule_${lang2}-${lang3} ${transdir}/model/rule-table.gz --ignore ${IGNORE}
  fi
  #show_exec mv ${workdir}/phrase-table.gz ${transdir}/model
  show_exec cp ${task2}/TM/model/glue-rules ${transdir}/model/
  show_exec sed -e "s/${task2}/${task}/g" ${task2}/TM/model/travatar.ini \> ${transdir}/model/travatar.ini
  show_exec rm ${workdir}/rule_${lang1}-${lang2} ${workdir}/rule_${lang1}-${lang2}.index
  show_exec rm ${workdir}/rule_${lang2}-${lang3} ${workdir}/rule_${lang2}-${lang3}.index
fi

bindir=${task}/binmodel
# -- TUNING --
if [ $opt_skip_tuning ]; then
  echo [skip] tuning
else
  show_exec ${dir}/tune-travatar.sh ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang3} ${transdir}/model/travatar.ini ${task} --threads=${THREADS}
fi

# -- TESTING --
if [ -f ${workdir}/score-tuned ]; then
  echo [autoskip] testing
elif [ $opt_skip_test ]; then
  echo [skip] testing
else
#if [ $opt_test ]; then
  show_exec ${dir}/test-travatar.sh ${task} ${transdir}/model/travatar.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang3} notune --threads=${THREADS}

  if [ -f ${workdir}/mert-work/travatar.ini ]; then
    # -- TESTING BINARISED --
    show_exec ${dir}/test-travatar.sh ${task} ${workdir}/mert-work/travatar.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang3} tuned --threads${THREADS}
    show_exec ${dir}/test-travatar.sh ${task} ${workdir}/mert-work/travatar.ini ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang3} dev --threads${THREADS}
  fi
fi

echo "##### End of script: $0"

