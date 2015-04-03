#!/bin/bash

#CLEAN_LENGTH=80
CLEAN_LENGTH=60

# -- PARTIAL CORPUS --
#TRAIN_SIZE=100000
#TEST_SIZE=1500
#DEV_SIZE=1500
TRAIN_SIZE=0
TEST_SIZE=0
DEV_SIZE=0

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

usage()
{
  echo "usage: $0 lang_id1 src1 lang_id2 src2 [lang_id3 src3]"
  echo ""
  echo "options:"
  echo "  --train_size={int}"
  echo "  --test_size={int}"
  echo "  --dev_size={int}"
  echo "  --dev_test_size={int}"
  echo "  --task_name={string}"
}

tokenize()
{
  lang=$1
  prefix=$2
  src=${corpus}/${prefix}.${lang}
  output=${corpus}/${prefix}.tok.${lang}

  if [ $lang = "zh" ]; then
#    show_exec $KYTEA -notags -model $KYTEA_ZH_DIC \< ${src} \> ${output}
    show_exec $KYTEA -notags -model $KYTEA_ZH_DIC -wsconst D \< ${src} \> ${output}
  elif [ $lang = "ja" ]; then
#    show_exec $KYTEA -notags \< ${src} \> ${output}
    show_exec $KYTEA -notags -wsconst D \< ${src} \> ${output}
  else
    show_exec ~/exp/moses/scripts/tokenizer/tokenizer.perl -l $lang \< $src \> ${output}
  fi
}

train_truecaser()
{
  lang=$1
  prefix=$2
  src=${corpus}/${prefix}.tok.${lang}
  model=${corpus}/truecase-model.${lang}
  show_exec $MOSES/scripts/recaser/train-truecaser.perl --model ${model} --corpus ${src}
}

truecase()
{
  lang=$1
  prefix=$2
  if [ $lang = "zh" ]; then
    show_exec mv ${corpus}/${prefix}.tok.${lang} ${corpus}/${prefix}.true.${lang}
  elif [ $lang = "ja" ]; then
    show_exec mv ${corpus}/${prefix}.tok.${lang} ${corpus}/${prefix}.true.${lang}
  else
    show_exec $MOSES/scripts/recaser/truecase.perl --model ${corpus}/truecase-model.${lang} \< ${corpus}/${prefix}.tok.${lang} \> ${corpus}/${prefix}.true.${lang}
  fi
}

if [ ${#ARGS[@]} -lt 4 ]
then
  usage
  exit 1
fi

lang1=${ARGS[0]}
src1=${ARGS[1]}
lang2=${ARGS[2]}
src2=${ARGS[3]}
lang3=${ARGS[4]}
src3=${ARGS[5]}


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

echo TRAIN_SIZE: $train_size
if [ ${opt_dev_test_size} ]; then
  echo TEST_SIZE : $opt_dev_test_size
  echo DEV_SIZE  : $opt_dev_test_size
else
  echo TEST_SIZE : $test_size
  echo DEV_SIZE  : $dev_size
fi

if [ $opt_task_name ]; then
  corpus="${opt_task_name}/corpus"
else
  corpus=corpus_${lang1}-${lang2}
  if [ "${lang3}" ]; then
    corpus=corpus_${lang1}-${lang2}-${lang3}
  fi
fi
show_exec mkdir -p $corpus

if [[ ${train_size} -gt 0 ]]; then
  show_exec head -n ${train_size} ${src1} \> $corpus/train.${lang1}
  show_exec head -n ${train_size} ${src2} \> $corpus/train.${lang2}
  if [ "${lang3}" ]; then
    show_exec head -n ${train_size} ${src3} \> $corpus/train.${lang3}
  fi
fi

#tokenize ${lang1} train
#tokenize ${lang2} train
#train_truecaser ${lang1} train
#train_truecaser ${lang2} train
#truecase ${lang1} train
#truecase ${lang2} train

if [ $opt_dev_test_size ]; then
#  offset=$(expr $train_size + 1)
  let offset=${train_size}+1
#  size=$(expr $opt_dev_test_size \* 2)
  let size=${opt_dev_test_size}*2
  show_exec tail -n +${offset} ${src1} \| head -n ${size} \> ${corpus}/devtest.${lang1}
  show_exec tail -n +${offset} ${src2} \| head -n ${size} \> ${corpus}/devtest.${lang2}

#  tokenize ${lang1} devtest
#  tokenize ${lang2} devtest
#  truecase ${lang1} devtest
#  truecase ${lang2} devtest

#  show_exec cat ${corpus}/devtest.true.${lang1} \| ${dir}/interleave.py ${corpus}/{test,dev}.true.${lang1}
#  show_exec cat ${corpus}/devtest.true.${lang2} \| ${dir}/interleave.py ${corpus}/{test,dev}.true.${lang2}
  show_exec cat ${corpus}/devtest.${lang1} \| ${dir}/interleave.py ${corpus}/{test,dev}.${lang1}
  show_exec cat ${corpus}/devtest.${lang2} \| ${dir}/interleave.py ${corpus}/{test,dev}.${lang2}

  if [ "${lang3}" ]; then
    show_exec tail -n +${offset} ${src3} \| head -n ${size} \> ${corpus}/devtest.${lang3}
    show_exec cat ${corpus}/devtest.${lang3} \| ${dir}/interleave.py ${corpus}/{test,dev}.${lang3}
  fi
else
#  offset=$(expr $train_size + 1)
  let offset=${train_size}+1
  if [[ "${test_size}" -gt 0 ]]; then
    show_exec tail -n +${offset} ${src1} \| head -n ${test_size} \> $corpus/test.${lang1}
    show_exec tail -n +${offset} ${src2} \| head -n ${test_size} \> $corpus/test.${lang2}
    if [ "${lang3}" ]; then
      show_exec tail -n +${offset} ${src3} \| head -n ${test_size} \> $corpus/test.${lang3}
    fi
  fi
#  offset=$(expr $offset + $test_size)
  let offset=${$offset}+${test_size}
  if [[ "${dev_size}" -gt 0 ]]; then
    show_exec tail -n +${offset} ${src1} \| head -n ${dev_size} \> ${corpus}/dev.${lang1}
    show_exec tail -n +${offset} ${src2} \| head -n ${dev_size} \> ${corpus}/dev.${lang2}
    if [ "${lang3}" ]; then
      show_exec tail -n +${offset} ${src3} \| head -n ${dev_size} \> ${corpus}/dev.${lang3}
    fi
  fi

#  tokenize ${lang1} test
#  tokenize ${lang2} test
#  tokenize ${lang1} dev
#  tokenize ${lang2} dev
#
#  truecase ${lang1} test
#  truecase ${lang2} test
#  truecase ${lang1} dev
#  truecase ${lang2} dev
fi

if [[ "${train_size}" -gt 0 ]]; then
  #show_exec ~/exp/moses/scripts/training/clean-corpus-n.perl $corpus/train.true ${lang1} ${lang2} $corpus/train.clean 1 ${CLEAN_LENGTH}
  show_exec ${TRAVATAR}/script/train/clean-corpus.pl -max_len ${CLEAN_LENGTH} ${corpus}/train.{$lang1,$lang2} ${corpus}/train.clean.{$lang1,$lang2}
fi

