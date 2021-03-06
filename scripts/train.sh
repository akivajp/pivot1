#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

echo "running script with PID: $$"

usage()
{
#  echo "usage: $0 mt_method lang_id1 lang_id2 src1 src2"
  echo "usage: $0 mt_method lang_id1 lang_id2 lm train1 train2 dev1 dev2 test1 test2"
  echo "usage: $0 mt_method lang_id1 lang_id2 src1 src2 lm train_size dev_test_size --format"
  echo "usage: $0 mt_method lang_id1 lang_id2 lm --corpus=corpus_dir"
  echo "usage: $0 mt_method lang_id1 lang_id2 lm --resume"
  echo ""
  echo "mt_method: pbmt hiero t2s"
  echo ""
  echo "options:"
  echo "  --reordering"
  echo "  --corpus=corpus_dir"
  echo "  --suffix={string}"
  echo "  --task_name={string}"
  echo "  --threads={int}"
  echo "  --coocfilter={float}"
  echo "  --srcfilter={float}"
  echo "  --src_input={word,penn}"
  echo "  --ribes"
  echo "  --normalize"
  echo "  --skip_test"
  echo "  --format"
}

mt_method=${ARGS[0]}
lang1=${ARGS[1]}
lang2=${ARGS[2]}

SRC_INPUT="word"
if [ "${opt_src_input}" ]; then
  SRC_INPUT=${opt_src_input}
fi

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="${mt_method}_${lang1}-${lang2}"
fi

if [ "${opt_suffix}" ]; then
  task=${task}.${opt_suffix#.}
fi

if [ "${opt_corpus}" ]; then
  if [ ${#ARGS[@]} -lt 4 ]; then
    usage
    exit 1
  fi
  lm=${ARGS[3]}
elif [ "${opt_format}" ]; then
    if [ ${#ARGS[@]} -lt 8 ]; then
        usage
        exit 1
    else
        src1=${ARGS[3]}
        src2=${ARGS[4]}
        lm=${ARGS[5]}
        opt_train_size=${ARGS[6]}
        opt_dev_test_size=${ARGS[7]}
    fi
elif [ -f "${task}/corpus/dev.${lang2}" ]; then
  if [ ${#ARGS[@]} -lt 3 ]; then
    usage
    exit 1
  fi
  lm=${ARGS[3]}
#elif [ ${#ARGS[@]} -lt 5 ]; then
#elif [ ${#ARGS[@]} -lt 8 ]; then
#elif [ ${#ARGS[@]} -lt 9 ]; then
elif [ ${#ARGS[@]} -lt 10 ]; then
  usage
  exit 1
else
#  src1=${ARGS[3]}
#  src2=${ARGS[4]}
#  lm=${ARGS[5]}
#  opt_train_size=${ARGS[6]}
#  opt_dev_test_size=${ARGS[7]}
    lm=${ARGS[3]}
    arg_train_src=${ARGS[4]}
    arg_train_trg=${ARGS[5]}
    arg_dev_src=${ARGS[6]}
    arg_dev_trg=${ARGS[7]}
    arg_test_src=${ARGS[8]}
    arg_test_trg=${ARGS[9]}
fi

corpus="${task}/corpus"
langdir="${task}/LM"
transdir="${task}/TM"
workdir="${task}/working"
filterdir="${workdir}/filtered"

if [ "${mt_method}" == "moses" ]; then
  mt_method=pbmt
fi

case ${mt_method} in
  pbmt)
    decoder=moses
#    src_test=${corpus}/test.true.${lang1}
#    src_dev=${corpus}/dev.true.${lang1}
    src_test=${corpus}/test.${lang1}
    src_dev=${corpus}/dev.${lang1}
    ;;
  hiero)
    decoder=travatar
#    src_test=${corpus}/test.true.${lang1}
#    src_dev=${corpus}/dev.true.${lang1}
    src_test=${corpus}/test.${lang1}
    src_dev=${corpus}/dev.${lang1}
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
#trg_test=${corpus}/test.true.${lang2}
#trg_dev=${corpus}/dev.true.${lang2}
trg_test=${corpus}/test.${lang2}
trg_dev=${corpus}/dev.${lang2}

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

ask_continue ${task}
show_exec mkdir -p ${task}
show_exec mkdir -p ${workdir}
LOG=${task}/log
echo "[${stamp} ${HOST}] $0 $*" >> ${LOG}

# -- CORPUS FORMATTING --
if [ -f ${trg_dev} ]; then
#if [ -f ${corpus}/train.clean.${lang2} ]; then
  echo [autoskip] corpus format
else
  mkdir -p ${corpus}
  if [ ! -f ${trg_dev} ]; then
    if [ "${opt_corpus}" ]; then
      #show_exec ln ${opt_corpus}/train.{$lang1,$lang2} ${corpus}
      #show_exec ln ${opt_corpus}/devtest.{$lang1,$lang2} ${corpus}
      #show_exec ln ${opt_corpus}/test.{$lang1,$lang2} ${corpus}
      #show_exec ln ${opt_corpus}/dev.{$lang1,$lang2} ${corpus}
      safe_link ${opt_corpus}/train.tree.${lang1} ${corpus}/train.tree.${lang1}
      safe_link ${opt_corpus}/test.tree.${lang1} ${corpus}/test.tree.${lang1}
      safe_link ${opt_corpus}/dev.tree.${lang1} ${corpus}/dev.tree.${lang1}
      show_exec ln ${opt_corpus}/train.{$lang1,$lang2} ${corpus}
      show_exec ln ${opt_corpus}/devtest.{$lang1,$lang2} ${corpus}
      show_exec ln ${opt_corpus}/test.{$lang1,$lang2} ${corpus}
      show_exec ln ${opt_corpus}/dev.{$lang1,$lang2} ${corpus}
    elif [ "${opt_format}" ]; then
      options=""
      options="$options --train_size=${opt_train_size}"
      options="$options --dev_test_size=${opt_dev_test_size}"
      options="$options --task_name=${task}"
      show_exec "${dir}/format-corpus.sh" ${lang1} ${src1} ${lang2} ${src2} ${options} --threads=${THREADS}
      if [ "${SRC_INPUT}" == "penn" ]; then
        for TYPE in train test dev devtest; do
          show_exec mv ${corpus}/${TYPE}.${lang1} ${corpus}/${TYPE}.tree.${lang1}
          show_exec cat ${corpus}/${TYPE}.tree.${lang1} \| pv -Wl \| ${TRAVATAR}/src/bin/tree-converter -input_format penn -output_format word \> ${corpus}/${TYPE}.${lang1}
        done
      fi
    else
      #options=""
      #options="$options --train_size=${opt_train_size}"
      #options="$options --dev_test_size=${opt_dev_test_size}"
      #options="$options --task_name=${task}"
      #show_exec "${dir}/format-corpus.sh" ${lang1} ${src1} ${lang2} ${src2} ${options} --threads=${THREADS}
      #if [ "${SRC_INPUT}" == "penn" ]; then
      #  for TYPE in train test dev devtest; do
      #    show_exec mv ${corpus}/${TYPE}.${lang1} ${corpus}/${TYPE}.tree.${lang1}
      #    show_exec cat ${corpus}/${TYPE}.tree.${lang1} \| pv -Wl \| ${TRAVATAR}/src/bin/tree-converter -input_format penn -output_format word \> ${corpus}/${TYPE}.${lang1}
      #  done
      #fi
      safe_link ${arg_train_src} ${corpus}/train.${lang1}
      safe_link ${arg_train_trg} ${corpus}/train.${lang2}
      safe_link ${arg_dev_src} ${corpus}/dev.${lang1}
      safe_link ${arg_dev_trg} ${corpus}/dev.${lang2}
      safe_link ${arg_test_src} ${corpus}/test.${lang1}
      safe_link ${arg_test_trg} ${corpus}/test.${lang2}
      show_exec cat ${corpus}/dev.${lang1} ${corpus}/dev.${lang1} \> ${corpus}/devtest.${lang1}
      show_exec cat ${corpus}/dev.${lang2} ${corpus}/dev.${lang2} \> ${corpus}/devtest.${lang2}
    fi
  fi
  #show_exec ${TRAVATAR}/script/train/clean-corpus.pl -max_len ${CLEAN_LENGTH} ${corpus}/train.{$lang1,$lang2} ${corpus}/train.clean.{$lang1,$lang2}
  if [ "${mt_method}" == "t2s" ]; then
    echo "SRC_INPUT: ${SRC_INPUT}"
    if [ "${SRC_INPUT}" == "word" ]; then
      show_exec "${dir}/parse-corpus.sh" ${corpus} ${options} --threads=${THREADS}
    fi
  fi
fi

lm_file="blm.${lang2}"
# -- LINKING LANGUAGE MODEL --
if [ ! -d ${langdir} ]; then
  show_exec mkdir -p ${langdir}
#  show_exec ln -s $(abspath ${lm}) ${langdir}/
  show_exec ln ${lm} ${langdir}/${lm_file}
fi
lm=$(abspath $langdir/$lm_file)

# -- TRAINING --
if [ -f "${plain_ini}" ]; then
  echo [autoskip] translation model
else
  if [ ${mt_method} == "pbmt" ]; then
    if [ "${opt_reordering}" ]; then
      #show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:${ORDER}:${lm}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
      show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:${ORDER}:${lm}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
    else
      #show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering distance -lm 0:${ORDER}:$(pwd)/$langdir/train.blm.${lang2}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
      #show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train.clean -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering distance -lm 0:${ORDER}:${lm}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
      show_exec $MOSES/scripts/training/train-model.perl -root-dir $transdir -corpus $corpus/train -f ${lang1} -e ${lang2} -alignment grow-diag-final-and -reordering distance -lm 0:${ORDER}:${lm}:8 -external-bin-dir $GIZA -cores ${THREADS} \> ${task}/training.out
    fi
    if [[ "${opt_coocfilter}" ]]; then
      show_exec mv ${transdir}/model/phrase-table.gz ${transdir}/model/phrase-table.full.gz
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/filter.py ${transdir}/model/phrase-table.full.gz ${transdir}/model/phrase-table.gz "'c.c >= ${opt_coocfilter}'" --progress
    elif [[ "${opt_srcfilter}" ]]; then
      show_exec mv ${transdir}/model/phrase-table.gz ${transdir}/model/phrase-table.full.gz
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/filter.py ${transdir}/model/phrase-table.full.gz ${transdir}/model/phrase-table.gz "'c.s >= ${opt_srcfilter}'" --progress
    fi
  elif [ "${decoder}" == "travatar" ]; then
    travatar_options=""
    score_options=""
#    if [[ "${opt_srcfilter}" ]]; then
#      score_options="${score_options} --src-min-freq=${opt_srcfilter}"
#    fi
    if [[ "${opt_coocfilter}" ]]; then
      score_options="${score_options} --cooc-min-freq=${opt_coocfilter}"
    fi
    if [[ "${score_options}" ]]; then
      travatar_options="${travatar_options} -score_options=\"${score_options}\""
    fi
    if [[ "${opt_normalize}" ]]; then
      travatar_options="${travatar_options} -normalize=true"
    fi
    if [ ${mt_method} == "hiero" ]; then
      #show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${PWD}/${transdir} -src_file ${corpus}/train.${lang1} -trg_file ${corpus}/train.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -progress -sort_options="-S10%" ${travatar_options}
      show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${PWD}/${transdir} -src_file ${corpus}/train.${lang1} -trg_file ${corpus}/train.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -progress -sort_options="-S10%" ${travatar_options} -resume
    elif [ ${mt_method} == "t2s" ]; then
      src_file=${corpus}/train.tree.${lang1}
      if [ -f "${corpus}/train.tree.${lang2}" ]; then
        trg_file=${corpus}/train.tree.${lang2}
        trg_format=penn
      else
        #trg_file=${corpus}/train.clean.${lang2}
        trg_file=${corpus}/train.${lang2}
        trg_format=word
      fi
      #show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${src_file} -trg_file ${trg_file} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -src_format penn -trg_format ${trg_format} -progress -sort_options="-S10%" ${travatar_options}
      #show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${src_file} -trg_file ${trg_file} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -src_format penn -trg_format ${trg_format} -progress -sort_options="-S10%" ${travatar_options} -resume
      #show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${src_file} -src_words ${corpus}/train.${lang1} -trg_file ${trg_file} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -src_format penn -trg_format ${trg_format} -progress -sort_options="-S10%" ${travatar_options} -resume
      show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${src_file} -trg_file ${trg_file} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -src_format penn -trg_format ${trg_format} -progress -sort_options="-S10%" ${travatar_options} -resume
      if [[ "${opt_srcfilter}" ]]; then
        show_exec mv ${transdir}/model/rule-table.gz ${transdir}/model/rule-table.full.gz
        show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/filter.py ${transdir}/model/rule-table.full.gz ${transdir}/model/rule-table.gz "'c.s >= ${opt_srcfilter}'" --progress
      fi
    fi
  fi
fi

if [ "${opt_skip_test}" ]; then
  echo "Exit without testing"
  exit 0
fi

# -- TESTING PLAIN --
if [ -f ${workdir}/score-plain.out ]; then
  echo [autoskip] testing plain
else
  show_exec ${dir}/filter.sh ${mt_method} ${plain_ini} ${src_test} ${workdir}/filtered
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
    if [ "${opt_reordering}" ]; then
      show_exec ${BIN}/processLexicalTable -in ${transdir}/model/reordering-table.wbe-msd-bidirectional-fe.gz -out ${bindir}/reordering-table
    fi
    show_exec ${BIN}/processPhraseTable -ttable 0 0 ${transdir}/model/phrase-table.gz -nscores 5 -out ${bindir}/phrase-table
    show_exec sed -e "s/PhraseDictionaryMemory/PhraseDictionaryBinary/" -e "s#${transdir}/model/phrase-table\.gz#${bindir}/phrase-table#" -e "s#${transdir}/model/reordering-table\.wbe-msd-bidirectional-fe\.gz#${bindir}/reordering-table#" ${workdir}/mert-work/moses.ini \> ${final_ini}
  else
    # -- MAKING TUNED DIR --
    show_exec mkdir -p ${tunedir}
    show_exec cp ${workdir}/mert-work/travatar.ini ${tunedir}
  fi
fi

# -- TESTING --
if [ -f ${workdir}/score-dev.out ]; then
  echo [autoskip] testing
else
  if [ -f "${final_ini}" ]; then
    # -- TESTING TUNED AND DEV --
    if [ "${mt_method}" == "pbmt" ]; then
      show_exec ${dir}/test.sh ${mt_method} ${task} ${final_ini} ${src_test} ${trg_test} tuned --threads=${THREADS}
      show_exec ${dir}/test.sh ${mt_method} ${task} ${final_ini} ${src_dev}  ${trg_dev}  dev --threads=${THREADS}
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

if [ "${opt_ribes}" ]; then
  # -- TUNING --
  rtunedir=${task}/rtuned
  rfinal_ini=${rtunedir}/travatar.ini
  if [ -f "${rfinal_ini}" ]; then
    echo [autoskip] ribes tuning
  elif [ $opt_skip_tuning ]; then
    echo [skip] ribes tuning
  else
    show_exec ${dir}/tune.sh ${mt_method} ${src_dev} ${trg_dev} ${plain_ini} ${task} --threads=${THREADS} --eval=ribes
    # -- MAKING TUNED DIR --
    show_exec mkdir -p ${rtunedir}
    show_exec cp ${workdir}/mert-work-ribes/travatar.ini ${rtunedir}
  fi
  # -- TESTING --
  if [ -f ${workdir}/score-rdev.out ]; then
    echo [autoskip] ribes testing
  else
    if [ -f "${rfinal_ini}" ]; then
      # -- TESTING TUNED AND DEV --
      show_exec ${dir}/filter.sh ${mt_method} ${rfinal_ini} ${src_test} ${workdir}/filtered
      show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${src_test} ${trg_test} rtuned --threads=${THREADS} ${test_options}
      show_exec ${dir}/filter.sh ${mt_method} ${rfinal_ini} ${src_dev}  ${workdir}/filtered
      show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${src_dev} ${trg_dev} rdev --threads=${THREADS} ${test_options}
    fi
  fi
fi

show_exec rm -rf ${workdir}/filtered

head ${workdir}/score* | tee -a ${LOG}

echo "##### End of script: $0 $*" | tee -a ${LOG}

