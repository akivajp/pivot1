#!/bin/bash

#THREADS=10
THREADS=8

#THRESHOLD="-7"
NBEST=40

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

usage()
{
  echo "usage: $0 task1 task2 corpus_dir"
  echo ""
  echo "options:"
  echo "  --overwrite"
  echo "  --task_name={string}"
  echo "  --suffix{string}"
  echo "  --threads={integer}"
  echo "  --skip_pivot"
  echo "  --skip_tuning"
  echo "  --skip_test"
  echo "  --nbest={integer}"
  echo "  --method-{counts,probs}"
}

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

if [ "$opt_suffix" ]; then
  task="${task}${opt_suffix}"
fi

if [ $opt_threads ]; then
  THREADS=$opt_threads
fi

show_exec mkdir -p ${task}
echo "[${stamp} ${HOST}] $0 $*" >> ${task}/log

corpus="${task}/corpus"
langdir=${task}/LM_${lang3}
workdir="${task}/working"
transdir=${task}/TM

echo "[${stamp} ${HOST}] $0 $*" >> ${workdir}/log

if [ $opt_skip_pivot ]; then
  echo [skip] pivot
elif [ ! $opt_overwrite ] && [ -f ${transdir}/model/travatar.ini ]; then
  echo [autoskip] pivot
else
  # COPYING CORPUS
  show_exec mkdir -p ${corpus}
  show_exec cp ${corpus_src}/devtest.true.{${lang1},${lang3}} ${corpus}
  show_exec cp ${corpus_src}/test.true.{${lang1},${lang3}} ${corpus}
  show_exec cp ${corpus_src}/dev.true.{${lang1},${lang3}} ${corpus}

  # COPYING LM
  show_exec mkdir -p ${langdir}
  show_exec cp ${task2}/LM_${lang3}/train.blm.${lang3} ${langdir}

  # FILTERING
  show_exec ${TRAVATAR}/script/train/filter-model.pl ${task1}/TM/model/travatar.ini ${workdir}/filtered-devtest/travatar.ini ${workdir}/filtered-devtest \"${TRAVATAR}/script/train/filter-rule-table.py ${corpus}/devtest.true.${lang1}\"

  # PIVOTING
  show_exec mkdir -p ${transdir}/model
  show_exec mkdir -p ${workdir}
  options="--workdir ${workdir}"
  if [ "${THRESHOLD}" ]; then
    options="${options} --threshold ${THRESHOLD}"
  fi
  if [ "${opt_nbest}" ]; then
    options="${options} --nbest ${opt_nbest}"
  else
    options="${options} --nbest ${NBEST}"
  fi
  if [ "${opt_method}" ]; then
    options="${options} --method ${opt_method}"
  fi
  show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/triangulate.py ${workdir}/filtered-devtest/rule-table.gz ${task2}/TM/model/rule-table.gz ${transdir}/model/rule-table.gz ${options}
  show_exec cp ${task2}/TM/model/glue-rules ${transdir}/model/
  show_exec sed -e "s/${task2}/${task}/g" ${task2}/TM/model/travatar.ini \> ${transdir}/model/travatar.ini
  show_exec rm -rf ${workdir}/filtered-devtest
  show_exec rm -rf ${workdir}/pivot
fi

tunedir=${task}/tuned
# -- TUNING --
if [ ! ${opt_overwrite} ] && [ -f ${tunedir}/travatar.ini ]; then
  echo [autoskip] tuning
elif [ $opt_skip_tuning ]; then
  echo [skip] tuning
else
  show_exec ${dir}/tune-travatar.sh ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang3} ${transdir}/model/travatar.ini ${task} --threads=${THREADS} --format=word
  show_exec mkdir -p ${tunedir}
  show_exec cp ${workdir}/mert-work/travatar.ini ${tunedir}
  show_exec rm -rf ${workdir}/mert-work/filtered
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
    show_exec ${dir}/test-travatar.sh ${task} ${workdir}/mert-work/travatar.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang3} tuned --threads=${THREADS}
    show_exec ${dir}/test-travatar.sh ${task} ${workdir}/mert-work/travatar.ini ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang3} dev --threads=${THREADS}
  fi
fi

echo "##### End of script: $0 $*"

