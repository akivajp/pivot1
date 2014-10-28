#!/bin/bash

KYTEA=/home/is/akiba-mi/usr/local/bin/kytea
KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod
MOSES=/home/is/akiba-mi/exp/moses
IRSTLM=~/exp/irstlm
TRAVATAR=$HOME/exp/travatar
TOOLS=/home/is/neubig/usr/local

CLEAN_LENGTH=60

# -- PARTIAL CORPUS --
TRAIN_SIZE=100000
TEST_SIZE=2000
DEV_SIZE=1000

THREADS=4

#echo "running script with PID: $$"

usage()
{
  echo "usage: $0 lang_id1 src1 lang_id2 src2"
  echo ""
  echo "options:"
  echo "  --train_size={int}"
  echo "  --test_size={int}"
  echo "  --dev_size={int}"
  echo "  --threads={int}"
  echo "  --task_name={string}"
  echo "  --skip_format"
}

show_exec()
{
  echo "[exec] $*"
  eval $*

  if [ $? -gt 0 ]
  then
    echo "[error on exec] $*"
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

preprocess()
{
  lang1=$1
  lang2=$2
  prefix=$3
  PREPROCESS=${TRAVATAR}/script/preprocess/preprocess.pl
  if [ ${prefix} = "train" ]; then
    show_exec ${PREPROCESS} -program-dir ${TOOLS} -src ${lang1} -trg ${lang2} ${corpus}/${prefix}.{$lang1,$lang2} ${parsedir}/${prefix} \
      -threads ${THREADS} -clean-len ${CLEAN_LENGTH} -truecase-trg
  else
    show_exec ${PREPROCESS} -program-dir ${TOOLS} -src ${lang1} -trg ${lang2} ${corpus}/${prefix}.{$lang1,$lang2} ${parsedir}/${prefix} \
      -threads ${THREADS} -forest-src -truecase-trg
  fi
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

if [ $opt_threads ]; then
  THREADS=${opt_threads}
fi


declare -i train_size=$opt_train_size
if [ $train_size -lt 1 ]
then
  train_size=$TRAIN_SIZE
fi

declare -i test_size=$opt_test_size
if [ $test_size -lt 1 ]
then
  test_size=$TEST_SIZE
fi

declare -i dev_size=$opt_dev_size
if [ $dev_size -lt 1 ]
then
  dev_size=$DEV_SIZE
fi

taskdir="."
if [ $opt_task_name ]; then
  taskdir=${opt_task_name}
fi

if [ $opt_task_name ]; then
  corpus="${opt_task_name}/corpus"
else
  corpus=corpus_${lang1}-${lang2}
fi
show_exec mkdir -p $corpus

show_exec head -n ${train_size} ${src1} \> $corpus/train.${lang1}
show_exec head -n ${train_size} ${src2} \> $corpus/train.${lang2}

offset=$(expr $train_size + 1)
show_exec tail -n +${offset} ${src1} \| head -n ${test_size} \> $corpus/test.${lang1}
show_exec tail -n +${offset} ${src2} \| head -n ${test_size} \> $corpus/test.${lang2}

offset=$(expr $offset + $test_size)
show_exec tail -n +${offset} ${src1} \| head -n ${dev_size} \> ${corpus}/dev.${lang1}
show_exec tail -n +${offset} ${src2} \| head -n ${dev_size} \> ${corpus}/dev.${lang2}

parsedir=${taskdir}/parsing
show_exec mkdir -p ${parsedir}

preprocess ${lang1} ${lang2} train
preprocess ${lang1} ${lang2} test
preprocess ${lang1} ${lang2} dev

