#!/bin/bash

KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod
MOSES=$HOME/exp/moses
BIN=$HOME/usr/local/bin
KYTEA=$BIN/kytea

IRSTLM=~/exp/irstlm
GIZA=~/usr/local/bin

#THREADS=10
THREADS=4

ORDER=5

dir=$(cd $(dirname $0); pwd)

echo "running script with PID: $$"

usage()
{
  echo "usage: $0 lang_id1 lang_id2 src1 src2"
  echo "usage: $0 lang_id1 lang_id2 --skip_format"
  echo ""
  echo "options:"
  echo "  --train_size={int}"
  echo "  --test_size={int}"
  echo "  --dev_size={int}"
  echo "  --dev_test_size={int}"
  echo "  --task_name={string}"
  echo "  --threads={int}"
  echo "  --skip_format"
  echo "  --skip_lm"
  echo "  --skip_train"
  echo "  --skip_tuning"
  echo "  --skip_test"
  echo "  --overwrite"
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

lang1=${ARGS[0]}
lang2=${ARGS[1]}
src1=${ARGS[2]}
src2=${ARGS[3]}

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="moses_${lang1}-${lang2}"
fi

if [ -f "${task}/corpus/dev.true.${lang2}" ]; then
  if [ ${#ARGS[@]} -lt 2 ]; then
    usage
    exit 1
  fi
elif [ ${#ARGS[@]} -lt 4 ]; then
  usage
  exit 1
fi

if [ ${opt_threads} ]; then
  THREADS=${opt_threads}
fi

corpus="${task}/corpus"
langdir="${task}/LM_${lang2}"
transdir="${task}/TM"

# -- CORPUS FORMATTING --
options=""
if [ $opt_train_size ]
then
  options="$options --train_size=${opt_train_size}"
fi
if [ $opt_test_size ]
then
  options="$options --test_size=${opt_test_size}"
fi
if [ $opt_dev_size ]
then
  options="$options --dev_size=${opt_dev_size}"
fi
if [ $opt_dev_test_size ]; then
  options="$options --dev_test_size=${opt_dev_test_size}"
fi
options="$options --task_name=${task}"
if [ ! $opt_overwrite ] && [ -f ${corpus}/dev.true.${lang2} ]; then
  echo [autoskip] corpus format
elif [ $opt_skip_format ]; then
  echo [skip] corpus format
else
  show_exec "${dir}/format-corpus.sh" ${lang1} ${src1} ${lang2} ${src2} ${options}
fi

# -- LANGUAGER MODELING --
if [ ! $opt_overwrite ] && [ -f ${langdir}/train.blm.${lang2} ]; then
  echo [autoskip] language modeling
elif [ $opt_skip_lm ]; then
  echo [skip] language modeling
else
  show_exec "${dir}/train-lm.sh" ${lang2} ${corpus}/train.true.${lang2} --task_name=${task}
fi

# -- TRAINING --
if [ ! $opt_overwrite ] && [ -f ${transdir}/model/moses.ini ]; then
  echo [autoskip] translation model
elif [ $opt_skip_train ]; then
  echo [skip] translation model
else
#  show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:${ORDER}:$(pwd)/$langdir/train.blm.${lang2}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
  show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering distance -lm 0:${ORDER}:$(pwd)/$langdir/train.blm.${lang2}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
fi

workdir="${task}/working"

bindir=${task}/binmodel
# -- TUNING --
if [ ! $opt_overwrite ] && [ -f ${bindir}/moses.ini ]; then
  echo [autoskip] tuning
elif [ $opt_skip_tuning ]; then
  echo [skip] tuning
else
#if [ $opt_tuning ]; then
  show_exec ${dir}/tune-moses.sh ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang2} ${transdir}/model/moses.ini ${task} --threads=${THREADS}

  # -- BINARIZING --
  show_exec mkdir -p ${bindir}
  show_exec ${BIN}/processPhraseTable -ttable 0 0 ${transdir}/model/phrase-table.gz -nscores 5 -out ${bindir}/phrase-table
  #show_exec ${BIN}/processLexicalTable -in ${transdir}/model/reordering-table.wbe-msd-bidirectional-fe.gz -out ${bindir}/reordering-table
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
  # -- TESTING PLAIN --
  show_exec rm -rf ${workdir}/filtered
  show_exec ${dir}/filter-moses.sh ${transdir}/model/moses.ini ${corpus}/test.true.${lang1} ${workdir}/filtered
  show_exec ${dir}/test-moses.sh ${task} ${workdir}/filtered/moses.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang2} plain --threads=${THREADS}
  show_exec rm -rf ${workdir}/filtered

  if [ -f ${bindir}/moses.ini ]; then
    # -- TESTING BINARISED --
    show_exec ${dir}/test-moses.sh ${task} ${bindir}/moses.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang2} tuned --threads=${THREADS}
    show_exec ${dir}/test-moses.sh ${task} ${bindir}/moses.ini ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang2} dev --threads=${THREADS}
  fi
fi

echo "##### End of script: $0 $*"

