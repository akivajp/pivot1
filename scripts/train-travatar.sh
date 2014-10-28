#!/bin/bash

KYTEA=/home/is/akiba-mi/usr/local/bin/kytea
KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod

IRSTLM=~/exp/irstlm
GIZA=~/usr/local/bin
TRAVATAR=$HOME/exp/travatar
BIN=$HOME/usr/local/bin

#THREADS=10
THREADS=4

dir=$(cd $(dirname $0); pwd)

echo "running script with PID: $$"

usage()
{
  echo "usage: $0 lang_id1 src1 lang_id2 src2"
  echo ""
  echo "options:"
  echo "  --train_size={int}"
  echo "  --test_size={int}"
  echo "  --dev_size={int}"
  echo "  --task_name={string}"
  echo "  --threads={int}"
  echo "  --skip_parse"
  echo "  --skip_lm"
  echo "  --skip_train"
  #echo "  --tuning"
  echo "  --skip_tuning"
  #echo "  --test"
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

abspath()
{
  echo $(cd $(dirname $1) && pwd)/$(basename $1)
}

proc_args $*

if [ ${#ARGS[@]} -lt 4 ]
then
  usage
  exit 1
fi

lang1=${ARGS[0]}
src1=${ARGS[1]}
lang2=${ARGS[2]}
src2=${ARGS[3]}

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="travatar_${lang1}-${lang2}"
fi

if [ ${opt_threads} ]; then
  THREADS=${opt_threads}
fi

corpus="${task}/corpus"
parsedir="${task}/parsing"
langdir="${task}/LM_${lang2}"
transdir="${task}/TM"

# -- CORPUS PARSING --
options="--threads=${THREADS}"
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
options="$options --task_name=${task}"
if [ ! ${opt_overwrite} ] && [ -f ${parsedir}/dev/true/${lang2} ]; then
  echo [autoskip] corpus parsing
elif [ $opt_skip_parse ]; then
  echo [skip] corpus parsing
else
  show_exec "${dir}/parse-corpus.sh" ${lang1} ${src1} ${lang2} ${src2} ${options}
fi

# -- LANGUAGER MODELING --
if [ ! ${opt_overwrite} ] && [ -f ${langdir}/train.blm.${lang2} ]; then
  echo [autoskip] language modeling
elif [ $opt_skip_lm ]; then
  echo [skip] language modeling
else
  show_exec "${dir}/train-lm.sh" ${lang2} ${parsedir}/train/true/${lang2} --task_name=${task}
fi

workdir="${task}/working"

if [ ! ${opt_overwrite} ] && [ -f ${transdir}/model/travatar.ini ]; then
  echo [autoskip] translation model
elif [ $opt_skip_train ]; then
  echo [skip] translation model
else
#  show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${parsedir}/train/treelow/${lang1} -trg_file ${parsedir}/train/true/${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${PWD}/${langdir}/train.blm.${lang2} -threads ${THREADS}
  show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${parsedir}/train/treelow/${lang1} -trg_file ${parsedir}/train/treelow/${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${PWD}/${langdir}/train.blm.${lang2} -threads ${THREADS} -trg_format penn
fi

orig=$PWD

if [ ! ${opt_overwrite} ] && [ -f ${workdir}/mert-work/travatar.ini ]; then
  echo [autoskip] tuning
elif [ $opt_skip_tuning ]; then
  echo [skip] tuning
else
#if [ $opt_tuning ]; then
  show_exec ${dir}/tune-travatar.sh ${parsedir}/dev/treelow/${lang1} ${parsedir}/dev/true/${lang2} ${orig}/${transdir}/model/travatar.ini ${task} --threads=${THREADS}
fi

if [ $opt_skip_test ]; then
  echo [skip] testing
else
#if [ $opt_test ]; then
  show_exec ${dir}/test-travatar.sh ${task} ${transdir}/model/travatar.ini ${parsedir}/test/treelow/${lang1} ${parsedir}/test/true/${lang2} ${workdir}/score1.out --threads=${THREADS}

  if [ -f ${workdir}/mert-work/travatar.ini ]; then
    show_exec ${dir}/test-travatar.sh ${task} ${workdir}/mert-work/travatar.ini ${parsedir}/test/treelow/${lang1} ${parsedir}/test/true/${lang2} ${workdir}/score2.out --threads${THREADS}
  fi
fi

echo "End of script: $0"

