#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

echo "running script with PID: $$"

usage()
{
  echo "usage: $0 mt_method lang_id1 lang_id2"
  echo ""
  echo "mt_method: s2t s2s"
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
}

if [ ${#ARGS[@]} -lt 3 ]; then
    usage
    exit 1
else
  mt_method=${ARGS[0]}
  lang1=${ARGS[1]}
  lang2=${ARGS[2]}
fi

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

corpus="${task}/corpus"
langdir="${task}/LM"
transdir="${task}/TM"
workdir="${task}/working"
filterdir="${workdir}/filtered"

case ${mt_method} in
  s2s|s2t)
    decoder=travatar
    src_test=${corpus}/test.tree.${lang1}
    src_dev=${corpus}/dev.tree.${lang1}
    ;;
  *)
    echo "mt_methos should be one of s2s/s2t"
    exit 1
    ;;
esac
trg_test=${corpus}/test.${lang2}
trg_dev=${corpus}/dev.${lang2}

case ${decoder} in
  travatar)
    tunedir=${task}/tuned
    plain_ini=${transdir}/model/travatar.ini
    final_ini=${tunedir}/travatar.ini
    filtered_ini=${filterdir}/travatar.ini
    ;;
esac

if [ "${mt_method}" == "s2t" ]; then
  BASE_TASK=t2s_${lang2}-${lang1}
  if [ ! -f "${BASE_TASK}/TM/model/travatar.ini" ]; then
    echo "[error] base task \"${BASE_TASK}\" is not trained" > /dev/stderr
    exit 1
  fi
fi

ask_continue ${task}

if [ ! -d ${task} ]; then
  show_exec mkdir -p ${transdir}/model
  LOG=${task}/log
  echo "[${stamp} ${HOST}] $0 $*" >> ${LOG}
  show_exec ln ${BASE_TASK}/TM/model/fof.txt ${transdir}/model/
  show_exec mkdir -p ${task}/TM/lex
  show_exec ln ${BASE_TASK}/TM/lex/src_given_trg.lex ${task}/TM/lex/trg_given_src.lex
  show_exec ln ${BASE_TASK}/TM/lex/trg_given_src.lex ${task}/TM/lex/src_given_trg.lex
else
  LOG=${task}/log
fi

SORT_OPTIONS="-S10%"
EXTRACT_FILE="${transdir}/model/extract.gz"
EXTRACT_FILE_REV="${BASE_TASK}/TM/model/extract.gz"
FOF_FILE="${transdir}/model/fof.txt"
LEX_TRGSRC="${task}/TM/lex/src_given_trg.lex"
LEX_SRCTRG="${task}/TM/lex/trg_given_src.lex"
RT_SRCTRG="${transdir}/model/rule-table.src-trg.gz";
RT_TRGSRC="${transdir}/model/rule-table.trg-src.gz";
PV_PIPE="pv -Wl";
PV_SORT="pv -Wl -N 'Sorting Records'";
SMOOTH="none"
TM_FILE="${transdir}/model/rule-table.gz"
NBEST_RULES=20

show_exec "zcat ${EXTRACT_FILE_REV} | ${TRAVATAR}/script/train/reverse-rt.pl | ${PV_PIPE} | gzip > ${EXTRACT_FILE}"
show_exec "zcat $EXTRACT_FILE | env LC_ALL=C sort $SORT_OPTIONS | $TRAVATAR/script/train/score-t2s.pl --fof-file=$FOF_FILE --lex-prob-file=$LEX_TRGSRC --cond-prefix=egf --joint | env LC_ALL=C sort $SORT_OPTIONS | gzip > $RT_SRCTRG &";
show_exec "zcat $EXTRACT_FILE_REV | $PV_SORT | env LC_ALL=C sort $SORT_OPTIONS | $TRAVATAR/script/train/score-t2s.pl --lex-prob-file=$LEX_SRCTRG --cond-prefix=fge | $TRAVATAR/script/train/reverse-rt.pl | $PV_SORT | env LC_ALL=C sort $SORT_OPTIONS | $PV_PIPE | gzip > $RT_TRGSRC";
show_exec wait

show_exec "$TRAVATAR/script/train/combine-rt.pl --fof-file=$FOF_FILE --smooth=$SMOOTH --top-n=$NBEST_RULES $RT_SRCTRG $RT_TRGSRC | $PV_PIPE | gzip > $TM_FILE"

exit 1

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
  elif [ ${mt_method} == "hiero" ]; then
    travatar_options=""
    if [[ "${opt_coocfilter}" ]]; then
      travatar_options="${travatar_options} -score_options=\"--cooc-min-freq=${opt_coocfilter}\""
    fi
    #show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${PWD}/${transdir} -src_file ${corpus}/train.clean.${lang1} -trg_file ${corpus}/train.clean.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -progress -sort_options="-S10%" ${travatar_options}
    show_exec ${TRAVATAR}/script/train/train-travatar.pl -method hiero -work_dir ${PWD}/${transdir} -src_file ${corpus}/train.${lang1} -trg_file ${corpus}/train.${lang2} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -progress -sort_options="-S10%" ${travatar_options}
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
#    show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${src_file} -trg_file ${trg_file} -travatar_dir ${TRAVATAR} -bin_dir ${BIN} -lm_file ${lm} -threads ${THREADS} -src_format penn -trg_format ${trg_format}
    show_exec ${TRAVATAR}/script/train/train-travatar.pl -work_dir ${PWD}/${transdir} -src_file ${src_file} -trg_file ${trg_file} -travatar_dir ${TRAVATAR} -bin_dir ${GIZA} -lm_file ${lm} -threads ${THREADS} -src_format penn -trg_format ${trg_format}
  fi
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
#  show_exec rm -rf ${workdir}/mert-work
  show_exec rm -rf ${workdir}/mert-work/filtered
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
    show_exec rm -rf ${workdir}/mert-work-ribes/filtered
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

