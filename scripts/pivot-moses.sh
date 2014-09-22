#!/bin/bash

KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod
MOSES=$HOME/exp/moses
BIN=$HOME/usr/local/bin
KYTEA=$BIN/kytea

IRSTLM=~/exp/irstlm
GIZA=~/usr/local/bin

#THREADS=10
THREADS=4

dir=$(cd $(dirname $0); pwd)

echo "running script with PID: $$"

usage()
{
  echo "usage: $0 task1 task2 corpus_dir"
  echo ""
  echo "options:"
  echo "  --task_name={string}"
  echo "  --skip_pivot"
  echo "  --tuning"
  echo "  --test"
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
corpus_src=${ARGS[2]}

trans1=${task1#*_}
trans2=${task2#*_}
lang1=${trans1%-*}
lang2=${trans1#*-}
lang3=${trans2#*-}

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="pivot_moses_${lang1}-${lang2}-${lang3}"
fi

show_exec mkdir -p ${task}

corpus="${task}/corpus"
langdir=${task}/LM_${lang3}
workdir="${task}/working"
transdir=${task}/TM
if [ $opt_skip_pivot ]; then
  echo [skip] pivot
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
  show_exec ${dir}/phrase-table/pivot-phrase-table.sh ${task1} ${task2} ${workdir}
  show_exec mv ${workdir}/phrase-table.gz ${transdir}/model
  show_exec sed -e "s/${task2}/${task}/g" ${task2}/TM/model/moses.ini \> ${transdir}/model/moses.ini
fi

bindir=${task}/binmodel
# -- TUNING --
if [ $opt_tuning ]; then
  show_exec ${dir}/tune-moses.sh ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang3} ${transdir}/model/moses.ini ${task}

  # -- BINARIZING --
  show_exec mkdir -p ${bindir}
  show_exec ${BIN}/processPhraseTable -ttable 0 0 ${transdir}/model/phrase-table.gz -nscores 5 -out ${bindir}/phrase-table
  show_exec sed -e "s/PhraseDictionaryMemory/PhraseDictionaryBinary/" -e "s#${transdir}/model/phrase-table\.gz#${bindir}/phrase-table#" -e "s#${transdir}/model/reordering-table\.wbe-msd-bidirectional-fe\.gz#${bindir}/reordering-table#" ${workdir}/mert-work/moses.ini \> ${bindir}/moses.ini

fi

# -- TESTING --
if [ $opt_test ]; then
  show_exec mkdir -p $workdir
  # -- TESTING PRAIN --
  show_exec rm -rf ${workdir}/tmp
  show_exec ${dir}/filter-moses.sh ${transdir}/model/moses.ini ${corpus}/test.true.${lang1} ${workdir}/tmp/filtered
  show_exec ${dir}/test-moses.sh ${task} ${workdir}/tmp/filtered/moses.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang3} ${workdir}/score1.out

  if [ -f ${bindir}/moses.ini ]; then
    # -- TESTING BINARISED --
    show_exec ${dir}/test-moses.sh ${task} ${bindir}/moses.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang3} ${workdir}/score2.out
  fi
fi

echo "##### End of script: $0"

