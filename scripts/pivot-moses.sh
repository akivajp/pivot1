#!/bin/bash

#KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod
#MOSES=$HOME/exp/moses
#BIN=$HOME/usr/local/bin
#KYTEA=$BIN/kytea
#PYTHONPATH=$HOME/exp/explib-python/lib
#
#IRSTLM=~/exp/irstlm
#GIZA=~/usr/local/bin

#THREADS=10
THREADS=8

#THRESHOLD="1e-3"
NBEST=30

METHOD="counts"

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"


echo "running script with PID: $$"

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

lang1=$(expr $taskname1 : '.*_\(..\)-..')
lang2=$(expr $taskname1 : '.*_..-\(..\)')
lang3=$(expr $taskname2 : '.*_..-\(..\)')

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="pivot_moses_${lang1}-${lang2}-${lang3}"
fi

if [ "$opt_suffix" ]; then
  task="${task}${opt_suffix}"
fi

if [ ${opt_threads} ]; then
  THREADS=${opt_threads}
fi

if [ "${opt_method}" ]; then
  METHOD="${opt_method}"
fi

show_exec mkdir -p ${task}
echo "[${stamp} ${HOST}] $0 $*" >> ${task}/log

corpus="${task}/corpus"
langdir=${task}/LM_${lang3}
workdir="${task}/working"
transdir=${task}/TM
show_exec mkdir -p ${workdir}

if [ $opt_skip_pivot ]; then
  echo [skip] pivot
elif [ ! $opt_overwrite ] && [ -f ${transdir}/model/moses.ini ]; then
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

  if [ "${METHOD}" == "counts" ]; then
    lexfile="${transdir}/model/lex_${lang1}-${lang3}"
    if [ -f "${lexfile}" ]; then
      echo [skip] calc lex probs
    else
      # 共起回数ピボットの場合、事前に語彙翻訳確率の算出が必要
      show_exec mkdir -p ${transdir}/model
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/align2lex.py ${task1}/corpus/train.clean.{$lang1,$lang2} ${task1}/TM/model/aligned.grow-diag-final-and ${workdir}/lex_${lang1}-${lang2}
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/align2lex.py ${task2}/corpus/train.clean.{$lang2,$lang3} ${task2}/TM/model/aligned.grow-diag-final-and ${workdir}/lex_${lang2}-${lang3}
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/pivot_lex.py ${workdir}/lex_${lang1}-${lang2} ${workdir}/lex_${lang2}-${lang3} ${lexfile}
    fi
  fi
  # PIVOTING
  show_exec mkdir -p ${transdir}/model
  ${dir}/wait-file.sh ${task1}/TM/model/moses.ini
  ${dir}/wait-file.sh ${task2}/TM/model/moses.ini
  options="--workdir ${workdir}"
  if [ "${THRESHOLD}" ]; then
    options="${options} --threshold ${THRESHOLD}"
  fi
  if [ "${opt_nbest}" ]; then
    options="${options} --nbest ${opt_nbest}"
  else
    options="${options} --nbest ${NBEST}"
  fi
  options="${options} --method ${METHOD}"
  if [ "${METHOD}" == "counts" ]; then
    options="${options} --lexfile ${lexfile}"
  fi
  show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/triangulate.py ${task1}/TM/model/phrase-table.gz ${task2}/TM/model/phrase-table.gz ${transdir}/model/phrase-table.gz ${options}
  show_exec sed -e "s/${task2}/${task}/g" ${task2}/TM/model/moses.ini \> ${transdir}/model/moses.ini
  show_exec rm -rf ${workdir}/pivot
fi

bindir=${task}/binmodel
# -- TUNING --
if [ ! $opt_overwrite ] && [ -f ${bindir}/moses.ini ]; then
  echo [autoskip] tuning
elif [ $opt_skip_tuning ]; then
  echo [skip] tuning
else
#if [ $opt_tuning ]; then
  show_exec ${dir}/tune-moses.sh ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang3} ${transdir}/model/moses.ini ${task} --threads=${THREADS}

  # -- BINARIZING --
  show_exec mkdir -p ${bindir}
  show_exec ${BIN}/processPhraseTable -ttable 0 0 ${transdir}/model/phrase-table.gz -nscores 5 -out ${bindir}/phrase-table
  show_exec sed -e "s/PhraseDictionaryMemory/PhraseDictionaryBinary/" -e "s#${transdir}/model/phrase-table\.gz#${bindir}/phrase-table#" -e "s#${transdir}/model/reordering-table\.wbe-msd-bidirectional-fe\.gz#${bindir}/reordering-table#" ${workdir}/mert-work/moses.ini \> ${bindir}/moses.ini

fi

# -- TESTING --
if [ ! $opt_overwrite ] && [ -f ${workdir}/score-dev.out ]; then
  echo [autoskip] testing
elif [ $opt_skip_test ]; then
  echo [skip] testing
else
#if [ $opt_test ]; then
  show_exec mkdir -p $workdir
  # -- TESTING PRAIN --
  show_exec rm -rf ${workdir}/filtered
  show_exec ${dir}/filter-moses.sh ${transdir}/model/moses.ini ${corpus}/test.true.${lang1} ${workdir}/filtered
  show_exec ${dir}/test-moses.sh ${task} ${workdir}/filtered/moses.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang3} plain --threads=${THREADS}
  show_exec rm -rf ${workdir}/filtered

  if [ -f ${bindir}/moses.ini ]; then
    # -- TESTING BINARISED --
    show_exec ${dir}/test-moses.sh ${task} ${bindir}/moses.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang3} tuned --threads=${THREADS}
    show_exec ${dir}/test-moses.sh ${task} ${bindir}/moses.ini ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang3} dev --threads=${THREADS}
  fi
fi

head ${workdir}/score*

echo "##### End of script: $0 $*"

