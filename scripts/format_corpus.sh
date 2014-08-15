#!/bin/bash

KYTEA=/home/is/akiba-mi/usr/local/bin/kytea
KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod
MOSES=/home/is/akiba-mi/exp/moses

IRSTLM=~/exp/irstlm
GIZA=~/usr/local/bin

#TRAIN_SIZE=40000
#TEST_SIZE=10000
#DEV_SIZE=5000

TRAIN_SIZE=4000
TEST_SIZE=1000
DEV_SIZE=500

usage()
{
  echo "usage: $0 lang_id1 src1 lang_id2 src2 [test_size]"
}

show_exec()
{
  echo "[exec] $*"
  eval $*

  if [ $? -gt 0 ]
  then
    echo "[error]"
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

tokenize()
{
  lang=$1
  src=$2
  output=$3

  if [ $lang = "zh" ]
  then
    show_exec $KYTEA -notags -model $KYTEA_ZH_DIC \< $src \> $output
  else
    show_exec ~/exp/moses/scripts/tokenizer/tokenizer.perl -l $lang \< $src \> $output
  fi
}

truecase()
{
  lang=$1
  prefix=$2
  show_exec $MOSES/scripts/recaser/truecase.perl --model ${workdir}/truecase-model.${lang} \< ${workdir}/${prefix}.tok.${lang} \> ${workdir}/${prefix}.true.${lang}
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

declare -i test_size
test_size=$TEST_SIZE
if [ ${#ARGS[@]} -gt 4 ]
then
  test_size=${ARGS[4]}
  if [ $test_size -lt 1 ]
  then
    test_size=$TEST_SIZE
  fi
fi

workdir=corpus_${lang1}-${lang2}
show_exec mkdir -p $workdir
show_exec head -${TRAIN_SIZE} ${src1} \> $workdir/train.${lang1}
show_exec head -${TRAIN_SIZE} ${src2} \> $workdir/train.${lang2}

#show_exec head -${test_size} $workdir/train.${lang1} \> $workdir/test.${lang1}
#show_exec head -${test_size} $workdir/train.${lang2} \> $workdir/test.${lang2}

show_exec head -${test_size} ${src1} \> $workdir/test.${lang1}
show_exec head -${test_size} ${src2} \> $workdir/test.${lang2}

#show_exec tail -n +${test_size} ${src1} \> $workdir/train.${lang1}
#show_exec tail -n +${test_size} ${src2} \> $workdir/train.${lang2}

show_exec head -${DEV_SIZE} ${src1} \> $workdir/dev.${lang1}
show_exec head -${DEV_SIZE} ${src2} \> $workdir/dev.${lang2}

tokenize ${lang1} $workdir/train.${lang1} $workdir/train.tok.${lang1}
tokenize ${lang2} $workdir/train.${lang2} $workdir/train.tok.${lang2}
tokenize ${lang1} $workdir/test.${lang1} $workdir/test.tok.${lang1}
tokenize ${lang2} $workdir/test.${lang2} $workdir/test.tok.${lang2}
tokenize ${lang1} $workdir/dev.${lang1} $workdir/dev.tok.${lang1}
tokenize ${lang2} $workdir/dev.${lang2} $workdir/dev.tok.${lang2}

show_exec $MOSES/scripts/recaser/train-truecaser.perl --model ${workdir}/truecase-model.${lang1} --corpus ${workdir}/train.tok.${lang1}
show_exec $MOSES/scripts/recaser/train-truecaser.perl --model ${workdir}/truecase-model.${lang2} --corpus ${workdir}/train.tok.${lang2}

#show_exec $MOSES/scripts/recaser/truecase.perl --model ${workdir}/truecase-model.${lang1} \< ${workdir}/train.tok.${lang1} \> ${workdir}/train.true.${lang1}
#show_exec $MOSES/scripts/recaser/truecase.perl --model ${workdir}/truecase-model.${lang2} \< ${workdir}/train.tok.${lang2} \> ${workdir}/train.true.${lang2}
truecase ${lang1} train
truecase ${lang2} train
truecase ${lang1} dev
truecase ${lang2} dev

show_exec ~/exp/moses/scripts/training/clean-corpus-n.perl $workdir/train.true ${lang1} ${lang2} $workdir/train.clean 1 80

langdir=LM_${lang2}
show_exec mkdir -p $langdir
show_exec $IRSTLM/bin/add-start-end.sh \< $workdir/train.true.${lang2} \> $langdir/train.sb.${lang2}
show_exec $IRSTLM/bin/build-lm.sh -i $langdir/train.sb.${lang2} -p -s improved-kneser-ney -o $langdir/train.lm.${lang2}
show_exec $IRSTLM/bin/compile-lm --text $langdir/train.lm.${lang2}.gz $langdir/train.arpa.${lang2}
show_exec $MOSES/bin/build_binary $langdir/train.arpa.${lang2} $langdir/train.blm.${lang2}

mkdir -p output
transdir=moses_${lang1}-${lang2}
show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $workdir/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:3:$(pwd)/$langdir/train.blm.${lang2}:8 -external-bin-dir $GIZA -cores 4 \> output/training_${lang1}-${lang2}.out


