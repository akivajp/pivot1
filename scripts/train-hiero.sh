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
  echo "  --skip_format"
  echo "  --skip_lm"
  echo "  --skip_train"
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
  task="hiero_${lang1}-${lang2}"
fi

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
options="$options --task_name=${task}"
if [ $opt_skip_format ]; then
  echo [skip] corpus format
else
  show_exec "${dir}/format-corpus.sh" ${lang1} ${src1} ${lang2} ${src2} ${options}
fi

# -- LANGUAGER MODELING --
corpus="${task}/corpus"
if [ $opt_skip_lm ]; then
  echo [skip] language modeling
else
  show_exec "${dir}/train-lm.sh" ${lang2} ${corpus}/train.true.${lang2} --task_name=${task}
fi

langdir="${task}/LM_${lang2}"

transdir="${task}/TM"
workdir="${task}/working"

if [ $opt_skip_train ]; then
  echo [skip] translation model
else
  show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${transdir} -src_file ${corpus}/train.clean.${lang1} -trg_file ${corpus}/train.clean.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${langdir}/train.blm.${lang2} -threads ${THREADS}
fi

orig=$PWD

if [ $opt_tuning ]; then
  show_exec ${dir}/tune-travatar.sh ${orig}/${corpus}/dev.true.${lang1} ${orig}/${corpus}/dev.true.${lang2} ${orig}/${transdir}/model/travatar.ini ${task}
fi

if [ $opt_test ]; then
  show_exec ${dir}/test-travatar.sh ${task} ${transdir}/model/travatar.ini ${workdir}/score1

  if [ -f ${workdir}/mert-work/travatar.ini ]; then
    show_exec ${dir}/test-travatar.sh ${task} ${workdir}/mert-work/travatar.ini ${workdir}/score2
  fi
fi

echo "End of script: $0"

