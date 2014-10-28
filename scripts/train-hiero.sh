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
  echo "usage: $0 lang_id1 lang_id2 src1 src2"
  echo "usage: $0 lang_id1 lang_id2 --skip_format"
  echo ""
  echo "other options:"
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

abspath()
{
  echo $(cd $(dirname $1) && pwd)/$(basename $1)
}

proc_args $*

lang1=${ARGS[0]}
lang2=${ARGS[1]}
src1=${ARGS[2]}
src2=${ARGS[3]}

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="hiero_${lang1}-${lang2}"
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
if [ $opt_train_size ]; then
  options="$options --train_size=${opt_train_size}"
fi
if [ $opt_test_size ]; then
  options="$options --test_size=${opt_test_size}"
fi
if [ $opt_dev_size ]; then
  options="$options --dev_size=${opt_dev_size}"
fi
if [ $opt_dev_test_size ]; then
  options="$options --dev_test_size=${opt_dev_test_size}"
fi
options="$options --task_name=${task}"
if [ ! ${opt_overwrite} ] && [ -f ${corpus}/dev.true.${lang2} ]; then
  echo [autoskip] corpus format
elif [ $opt_skip_format ]; then
  echo [skip] corpus format
else
  show_exec "${dir}/format-corpus.sh" ${lang1} ${src1} ${lang2} ${src2} ${options}
fi

# -- LANGUAGER MODELING --
if [ ! ${opt_overwrite} ] && [ -f ${langdir}/train.blm.${lang2} ]; then
  echo [autoskip] language modeling
elif [ $opt_skip_lm ]; then
  echo [skip] language modeling
else
  show_exec "${dir}/train-lm.sh" ${lang2} ${corpus}/train.true.${lang2} --task_name=${task}
fi

workdir="${task}/working"

if [ ! ${opt_overwrite} ] && [ -f ${transdir}/model/travatar.ini ]; then
  echo [autoskip] translation model
elif [ $opt_skip_train ]; then
  echo [skip] translation model
else
  #show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${transdir} -src_file ${corpus}/train.clean.${lang1} -trg_file ${corpus}/train.clean.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${langdir}/train.blm.${lang2} -threads ${THREADS}
  show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${PWD}/${transdir} -src_file ${corpus}/train.clean.${lang1} -trg_file ${corpus}/train.clean.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${PWD}/${langdir}/train.blm.${lang2} -threads ${THREADS}
fi

tunedir=${task}/tuned
if [ ! ${opt_overwrite} ] && [ -f ${tunedir}/travatar.ini ]; then
  echo [autoskip] tuning
elif [ $opt_skip_tuning ]; then
  echo [skip] tuning
else
  orig=$PWD
  show_exec ${dir}/tune-travatar.sh ${orig}/${corpus}/dev.true.${lang1} ${orig}/${corpus}/dev.true.${lang2} ${orig}/${transdir}/model/travatar.ini ${task} --threads=${THREADS}
  show_exec cp ${workdir}/mert-work/travatar.ini ${tunedir}
  show_exec rm -rf ${workdir}/mert-work/filtered
fi

if [ -f ${workdir}/score-dev.out ]; then
  echo [autoskip] testing
elif [ $opt_skip_test ]; then
  echo [skip] testing
else
  show_exec ${dir}/test-travatar.sh ${task} ${transdir}/model/travatar.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang2} notune --threads=${THREADS}

  if [ -f ${workdir}/mert-work/travatar.ini ]; then
    show_exec ${dir}/test-travatar.sh ${task} ${tunedir}/travatar.ini ${corpus}/test.true.${lang1} ${corpus}/test.true.${lang2} tuned --threads${THREADS}
    show_exec ${dir}/test-travatar.sh ${task} ${tunedir}/travatar.ini ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang2} dev --threads${THREADS}
  fi
fi

echo "End of script: $0"

