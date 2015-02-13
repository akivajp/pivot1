#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

echo "running script with PID: $$"

usage()
{
#  echo "usage: $0 mt_method lang_id1 lang_id2 src1 src2"
  echo "usage: $0 mt_method lang_id1 lang_id2 src1 src2 train_size dev_test_size"
  echo "usage: $0 mt_method lang_id1 lang_id2 --resume"
  echo ""
  echo "mt_method: pbmt hiero t2s"
  echo ""
  echo "options:"
  echo "  --suffix={string}"
  echo "  --task_name={string}"
  echo "  --threads={int}"
}

mt_method=${ARGS[0]}
lang1=${ARGS[1]}
lang2=${ARGS[2]}
src1=${ARGS[3]}
src2=${ARGS[4]}
opt_train_size=${ARGS[5]}
opt_dev_test_size=${ARGS[6]}

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="${mt_method}_${lang1}-${lang2}"
fi

if [ -f "${task}/corpus/dev.true.${lang2}" ]; then
  if [ ${#ARGS[@]} -lt 3 ]; then
    usage
    exit 1
  fi
#elif [ ${#ARGS[@]} -lt 5 ]; then
elif [ ${#ARGS[@]} -lt 7 ]; then
  usage
  exit 1
fi

corpus="${task}/corpus"
langdir="${task}/LM_${lang2}"
transdir="${task}/TM"
workdir="${task}/working"
filterdir="${workdir}/filtered"

if [ "${mt_method}" == "moses" ]; then
  mt_method=pbmt
fi

case ${mt_method} in
  pbmt)
    decoder=moses
    src_test=${corpus}/test.true.${lang1}
    src_dev=${corpus}/dev.true.${lang1}
    ;;
  hiero)
    decoder=travatar
    src_test=${corpus}/test.true.${lang1}
    src_dev=${corpus}/dev.true.${lang1}
    ;;
  t2s)
    decoder=travatar
    src_test=${corpus}/test.tree.${lang1}
    src_dev=${corpus}/dev.tree.${lang1}
    ;;
  *)
    echo "mt_methos should be one of pbmt/hiero/t2s"
    exit 1
    ;;
esac
trg_test=${corpus}/test.true.${lang2}
trg_dev=${corpus}/dev.true.${lang2}

if [ "${mt_method}" == "t2s" ]; then
  case ${lang1} in
    en)
      ;;
    ja)
      ;;
    *)
      echo "lang1 should be one of en/ja"
      exit 1
  esac
fi

case ${decoder} in
  moses)
    bindir=${task}/binmodel
    plain_ini=${transdir}/model/moses.ini
    final_ini=${bindir}/moses.ini
    filtered_ini=${filterdir}/moses.ini
    ;;
  travatar)
    tunedir=${task}/tuned
    plain_ini=${transdir}/model/travatar.ini
    final_ini=${tunedir}/travatar.ini
    filtered_ini=${filterdir}/travatar.ini
    ;;
esac

show_exec mkdir -p ${task}
show_exec mkdir -p ${workdir}
echo "[${stamp} ${HOST}] $0 $*" >> ${task}/log

# -- CORPUS FORMATTING --
options=""
options="$options --train_size=${opt_train_size}"
options="$options --dev_test_size=${opt_dev_test_size}"
options="$options --task_name=${task}"
if [ -f ${corpus}/dev.true.${lang2} ]; then
  echo [autoskip] corpus format
else
  show_exec "${dir}/format-corpus.sh" ${lang1} ${src1} ${lang2} ${src2} ${options} --threads=${THREADS}
  if [ "${mt_method}" == "t2s" ]; then
    show_exec "${dir}/parse-corpus.sh" ${corpus} ${options} --threads=${THREADS}
  fi
fi

# -- LANGUAGER MODELING --
if [ -f ${langdir}/train.blm.${lang2} ]; then
  echo [autoskip] language modeling
else
  show_exec "${dir}/train-lm.sh" ${lang2} ${corpus}/train.true.${lang2} --task_name=${task}
fi

# -- TRAINING --
if [ -f "${plain_ini}" ]; then
  echo [autoskip] translation model
else
  if [ ${mt_method} == "pbmt" ]; then
  #  show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:${ORDER}:$(pwd)/$langdir/train.blm.${lang2}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
    show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering distance -lm 0:${ORDER}:$(pwd)/$langdir/train.blm.${lang2}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
  elif [ ${mt_method} == "hiero" ]; then
    #show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${transdir} -src_file ${corpus}/train.clean.${lang1} -trg_file ${corpus}/train.clean.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${langdir}/train.blm.${lang2} -threads ${THREADS}
    show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${PWD}/${transdir} -src_file ${corpus}/train.clean.${lang1} -trg_file ${corpus}/train.clean.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${PWD}/${langdir}/train.blm.${lang2} -threads ${THREADS}
  elif [ ${mt_method} == "t2s" ]; then
    src_file=${corpus}/train.tree.${lang1}
    if [ -f "${corpus}/train.tree.${lang2}" ]; then
      trg_file=${corpus}/train.tree.${lang2}
      trg_format=penn
    else
      trg_file=${corpus}/train.clean.${lang2}
      trg_format=word
    fi
    show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${src_file} -trg_file ${trg_file} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${PWD}/${langdir}/train.blm.${lang2} -threads ${THREADS} -src_format penn -trg_format ${trg_format}
  fi
fi

# -- TESTING PLAIN --
if [ -f ${workdir}/score-plain.out ]; then
  echo [autoskip] testing plain
else
#  show_exec ${dir}/filter.sh ${mt_method} ${plain_ini} ${corpus}/test.true.${lang1} ${workdir}/filtered
  show_exec ${dir}/filter.sh ${mt_method} ${plain_ini} ${src_test} ${workdir}/filtered
#  show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${corpus}/test.true.{$lang1,$lang2} plain --threads=${THREADS}
  show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${src_test} ${trg_test} plain --threads=${THREADS}
fi

# -- TUNING --
if [ -f "${final_ini}" ]; then
  echo [autoskip] tuning
else
#  show_exec ${dir}/tune.sh ${mt_method} ${corpus}/dev.true.${lang1} ${corpus}/dev.true.${lang2} ${plain_ini} ${task} --threads=${THREADS}
  show_exec ${dir}/tune.sh ${mt_method} ${src_dev} ${trg_dev} ${plain_ini} ${task} --threads=${THREADS}

  if [ "${mt_method}" == "pbmt" ]; then
    # -- BINARIZING --
    show_exec mkdir -p ${bindir}
    show_exec ${BIN}/processPhraseTable -ttable 0 0 ${transdir}/model/phrase-table.gz -nscores 5 -out ${bindir}/phrase-table
    #show_exec ${BIN}/processLexicalTable -in ${transdir}/model/reordering-table.wbe-msd-bidirectional-fe.gz -out ${bindir}/reordering-table
    show_exec sed -e "s/PhraseDictionaryMemory/PhraseDictionaryBinary/" -e "s#${transdir}/model/phrase-table\.gz#${bindir}/phrase-table#" -e "s#${transdir}/model/reordering-table\.wbe-msd-bidirectional-fe\.gz#${bindir}/reordering-table#" ${workdir}/mert-work/moses.ini \> ${final_ini}
  else
    # -- MAKING TUNED DIR --
    show_exec mkdir -p ${tunedir}
    show_exec cp ${workdir}/mert-work/travatar.ini ${tunedir}
  fi
  show_exec rm -rf ${workdir}/mert-work
fi

# -- TESTING --
if [ -f ${workdir}/score-dev.out ]; then
  echo [autoskip] testing
else
  if [ -f "${final_ini}" ]; then
    # -- TESTING TUNED AND DEV --
    if [ "${mt_method}" == "pbmt" ]; then
      show_exec ${dir}/test.sh ${mt_method} ${task} ${final_ini} ${corpus}/test.true.{$lang1,$lang2} tuned --threads=${THREADS}
      show_exec ${dir}/test.sh ${mt_method} ${task} ${final_ini} ${corpus}/dev.true.{$lang1,$lang2} dev --threads=${THREADS}
    else
#      show_exec ${dir}/filter.sh ${mt_method} ${final_ini} ${corpus}/test.true.${lang1} ${workdir}/filtered
      show_exec ${dir}/filter.sh ${mt_method} ${final_ini} ${src_test} ${workdir}/filtered
#      show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${corpus}/test.true.{$lang1,$lang2} tuned --threads=${THREADS}
      show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${src_test} ${trg_test} tuned --threads=${THREADS}
#      show_exec ${dir}/filter.sh ${mt_method} ${final_ini} ${corpus}/dev.true.${lang1} ${workdir}/filtered
      show_exec ${dir}/filter.sh ${mt_method} ${final_ini} ${src_dev} ${workdir}/filtered
#      show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${corpus}/dev.true.{$lang1,$lang2} dev --threads=${THREADS}
      show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${src_dev} ${trg_dev} dev --threads=${THREADS}
    fi
  fi
fi

show_exec rm -rf ${workdir}/filtered
head ${workdir}/score*

echo "##### End of script: $0 $*"

