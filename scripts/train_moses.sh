#!/bin/bash

KYTEA=/home/is/akiba-mi/usr/local/bin/kytea
KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod
MOSES=/home/is/akiba-mi/exp/moses

IRSTLM=~/exp/irstlm
GIZA=~/usr/local/bin

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

lang1=${ARGS[0]}
src1=${ARGS[1]}
lang2=${ARGS[2]}
src2=${ARGS[3]}

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="moses_${lang1}-${lang2}"
fi

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
show_exec "${dir}/format_corpus.sh" ${lang1} ${src1} ${lang2} ${src2} ${options}

corpus="${task}/corpus"
show_exec "${dir}/train_lm.sh" ${lang2} ${corpus}/train.true.${lang2} --task_name=${task}

langdir="${task}/LM_${lang2}"
transdir="${task}/TM"
#transdir="${task}/TM_${lang1}-${lang2}"
show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:3:$(pwd)/$langdir/train.blm.${lang2}:8 -external-bin-dir $GIZA -cores 4 \> ${task}/training.out

workdir="${task}/working"
orig=$PWD
#show_exec mkdir -p ${workdir}
#show_exec cd ${workdir}
#show_exec $MOSES/scripts/training/mert-moses.pl ${orig}/${corpus}/dev.true.${lang1} ${orig}/${corpus}/dev.true.${lang2} $MOSES/bin/moses ${orig}/${transdir}/model/moses.ini --mertdir $MOSES/bin \> mert.out
show_exec ${dir}/tune_moses.sh ${orig}/${corpus}/dev.true.${lang1} ${orig}/${corpus}/dev.true.${lang2} ${orig}/${transdir}/model/moses.ini ${task}

