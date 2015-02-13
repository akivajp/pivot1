#!/bin/bash

NBEST=20
#METHOD="counts"
METHOD="prodprob"
LEX_METHOD="prodweight"

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

usage()
{
  echo "usage: $0 task1 task2 corpus_dir"
  echo ""
  echo "options:"
  echo "  --overwrite"
  echo "  --task_name={string}"
  echo "  --suffix{string}"
  echo "  --threads={integer}"
  echo "  --nbest={integer}"
  echo "  --method={counts,probs}"
  echo "  --lexmethod={count,prod}"
  echo "  --noprefilter"
  echo "  --nulls={int}"
}

if [ ${#ARGS[@]} -lt 3 ]
then
  usage
  exit 1
fi

task1=${ARGS[0]}
task2=${ARGS[1]}
taskname1=$(basename $task1)
taskname2=$(basename $task2)
corpus_src=${ARGS[2]}

mt_method1=$(expr $taskname1 : '\(.*\)_..-..')
mt_method2=$(expr $taskname2 : '\(.*\)_..-..')
lang1_1=$(expr $taskname1 : '.*_\(..\)-..')
lang1_2=$(expr $taskname1 : '.*_..-\(..\)')
lang2_1=$(expr $taskname2 : '.*_\(..\)-..')
lang2_2=$(expr $taskname2 : '.*_..-\(..\)')

if [ "${lang1_2}" == "${lang2_1}" ]; then
  lang_src=${lang1_1}
  lang_pvt=${lang1_2}
  lang_trg=${lang2_2}
elif [ "${lang1_1}" == "${lang2_1}" ]; then
  lang_src=${lang1_2}
  lang_pvt=${lang1_1}
  lang_trg=${lang2_2}
else
  echo "can not solve pivot language"
  exit 1
fi

if [ "${mt_method1}" == "${mt_method2}" ]; then
  mt_method=${mt_method1}
else
  echo "can not solve pivot method"
  exit 1
fi

if [ $opt_task_name ]; then
  task=$opt_task_name
else
  task="pivot_${mt_method}_${lang_src}-${lang_pvt}-${lang_trg}"
fi

if [ "$opt_suffix" ]; then
#  task="${task}${opt_suffix}"
  task="${task}.${opt_suffix}"
fi

echo "MT METHOD: ${mt_method}"
echo "PIVOT METHOD: ${METHOD}"
echo "LANG SRC: ${lang_src}"
echo "LANG PVT: ${lang_pvt}"
echo "LANG TRG: ${lang_trg}"
echo "TASK: ${task}"

corpus="${task}/corpus"
langdir=${task}/LM_${lang_trg}
workdir="${task}/working"
transdir=${task}/TM
filterdir="${workdir}/filtered"
show_exec mkdir -p ${workdir}

show_exec mkdir -p ${task}
echo "[${stamp} ${HOST}] $0 $*" >> ${task}/log

case ${mt_method} in
  pbmt)
    decoder=moses
    ;;
  hiero)
    decoder=travatar
    ;;
  t2s)
    decoder=travatar
    ;;
  *)
    echo "mt_methos should be one of pbmt/hiero/t2s"
    exit 1
    ;;
esac

case ${decoder} in
  moses)
    bindir=${task}/binmodel
    plain_ini=${transdir}/model/moses.ini
    final_ini=${bindir}/moses.ini
    filtered_ini=${filterdir}/moses.ini
    ${dir}/wait-file.sh ${task1}/TM/model/moses.ini
    ${dir}/wait-file.sh ${task2}/TM/model/moses.ini
    ;;
  travatar)
    tunedir=${task}/tuned
    plain_ini=${transdir}/model/travatar.ini
    final_ini=${tunedir}/travatar.ini
    filtered_ini=${filterdir}/travatar.ini
    ${dir}/wait-file.sh ${task1}/TM/model/travatar.ini
    ${dir}/wait-file.sh ${task2}/TM/model/travatar.ini
    ;;
esac

if [ "${opt_nbest}" ]; then
  NBEST="${opt_nbest}"
fi

if [ -f ${plain_ini} ]; then
  echo [autoskip] pivot
else
  # COPYING CORPUS
  show_exec mkdir -p ${corpus}
  show_exec cp ${corpus_src}/devtest.true.{$lang_src,$lang_trg} ${corpus}
  show_exec cp ${corpus_src}/test.true.{$lang_src,$lang_trg} ${corpus}
  show_exec cp ${corpus_src}/dev.true.{$lang_src,$lang_trg} ${corpus}

  # COPYING LM
  show_exec mkdir -p ${langdir}
  show_exec cp ${task2}/LM_${lang_trg}/train.blm.${lang_trg} ${langdir}

  if [ "${mt_method}" == "t2s" ]; then
    # REVERSING
    show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/reverse.py ${task1}/TM/model/rule-table.gz ${workdir}/rule_s2t
#    show_exec cat ${workdir}/rule_s2t \| ${TRAVATAR}/script/train/filter-rule-table.py ${corpus}/devtest.true.${lang_src} \| gzip \> ${workdir}/rule_filtered.gz
    show_exec cat ${workdir}/rule_s2t \| ${TRAVATAR}/script/train/filter-rule-table.py ${corpus}/devtest.true.${lang_src} \> ${workdir}/rule_filtered.gz
  elif [ "${mt_method}" == "hiero" ]; then
    # FILTERING
#    show_exec ${TRAVATAR}/script/train/filter-model.pl ${task1}/TM/model/travatar.ini ${workdir}/filtered-devtest/travatar.ini ${workdir}/filtered-devtest \"${TRAVATAR}/script/train/filter-rule-table.py ${corpus}/devtest.true.${lang_src}\"
#    show_exec zcat ${task1}/TM/model/rule-table.gz \| ${TRAVATAR}/script/train/filter-rule-table.py ${corpus}/devtest.true.${lang_src} \| gzip \> ${workdir}/rule_filtered.gz
    show_exec zcat ${task1}/TM/model/rule-table.gz \| ${TRAVATAR}/script/train/filter-rule-table.py ${corpus}/devtest.true.${lang_src} \> ${workdir}/rule_filtered.gz
  fi

  if [ "${LEX_METHOD}" != "prodweight" ] && [ "${LEX_METHOD}" != "table" ]; then
#    lexfile="${transdir}/model/lex_${lang_src}-${lang_trg}"
    alignlex="${transdir}/model/align.lex"
    if [ -f "${alignlex}" ]; then
      echo [skip] calc lex probs
    else
      # 共起回数ピボットの場合、事前に語彙翻訳確率の算出が必要
      show_exec mkdir -p ${transdir}/model
      if [ "${decoder}" == "moses" ]; then
        show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/align2lex.py ${task1}/corpus/train.clean.{$lang_src,$lang_pvt} ${task1}/TM/model/aligned.grow-diag-final-and ${workdir}/lex_${lang_src}-${lang_pvt}
        show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/align2lex.py ${task2}/corpus/train.clean.{$lang_pvt,$lang_trg} ${task2}/TM/model/aligned.grow-diag-final-and ${workdir}/lex_${lang_pvt}-${lang_trg}
      elif [ "${decoder}" == "travatar" ]; then
        show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/align2lex.py ${task1}/corpus/train.clean.{$lang_src,$lang_pvt} ${task1}/TM/align/align.txt ${workdir}/lex_${lang_src}-${lang_pvt}
        show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/align2lex.py ${task2}/corpus/train.clean.{$lang_pvt,$lang_trg} ${task2}/TM/align/align.txt ${workdir}/lex_${lang_pvt}-${lang_trg}
      fi
      align_lex_method=$(echo $LEX_METHOD | sed -e 's/\(.*\)+table/\1/')
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/pivot_lex.py ${workdir}/lex_${lang_src}-${lang_pvt} ${workdir}/lex_${lang_pvt}-${lang_trg} ${alignlex} --method ${align_lex_method}
    fi
  fi

  # PIVOTING
  show_exec mkdir -p ${transdir}/model
  options="--workdir ${workdir}"
  options="${options} --nbest ${NBEST}"
  options="${options} --method ${METHOD}"
  options="${options} --lexmethod ${LEX_METHOD}"
  if [ "${opt_nulls}" ]; then
    options="${options} --nulls ${opt_nulls}"
  fi
  if [ "${LEX_METHOD}" != "prodweight" ]; then
    if [ "${LEX_METHOD}" != "table" ]; then
      options="${options} --alignlex ${alignlex}"
    fi
  fi
  if [ "${opt_noprefilter}" ]; then
    options="${options} --noprefilter=True"
  fi
  if [ "${mt_method}" == "pbmt" ]; then
    show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/phrasetable/triangulate.py ${task1}/TM/model/phrase-table.gz ${task2}/TM/model/phrase-table.gz ${transdir}/model/phrase-table.gz ${options}
    show_exec sed -e "s/${task2}/${task}/g" ${task2}/TM/model/moses.ini \> ${plain_ini}
  elif [ "${mt_method}" == "hiero" ]; then
    show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/triangulate.py ${workdir}/rule_filtered.gz ${task2}/TM/model/rule-table.gz ${transdir}/model/rule-table.gz ${options}
    show_exec cp ${task2}/TM/model/glue-rules ${transdir}/model/
    show_exec sed -e "s/${task2}/${task}/g" ${task2}/TM/model/travatar.ini \> ${plain_ini}
  elif [ "${mt_method}" == "t2s" ]; then
    show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/triangulate.py ${workdir}/rule_filtered.gz ${task2}/TM/model/rule-table.gz ${transdir}/model/rule-table.gz ${options}
    show_exec sed -e "s/${task2}/${task}/g" ${task2}/TM/model/travatar.ini \> ${plain_ini}
  fi
  if [ -f ${workdir}/pivot/table.lex ]; then
    show_exec cp ${workdir}/pivot/table.lex ${transdir}/model/
  fi
  if [ -f ${workdir}/pivot/combined.lex ]; then
    show_exec cp ${workdir}/pivot/combined.lex ${transdir}/model/
  fi
  show_exec rm -rf ${workdir}/pivot
fi

# -- TESTING PLAIN --
if [ -f ${workdir}/score-plain.out ]; then
  echo [autoskip] testing plain
else
  show_exec ${dir}/filter.sh ${mt_method} ${plain_ini} ${corpus}/test.true.${lang_src} ${workdir}/filtered
  show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${corpus}/test.true.{$lang_src,$lang_trg} plain --threads=${THREADS}
fi

# -- TUNING --
if [ -f "${final_ini}" ]; then
  echo [autoskip] tuning
elif [ $opt_skip_tuning ]; then
  echo [skip] tuning
else
  show_exec ${dir}/tune.sh ${mt_method} ${corpus}/dev.true.${lang_src} ${corpus}/dev.true.${lang_trg} ${plain_ini} ${task} --threads=${THREADS}

  if [ "${decoder}" == "moses" ]; then
    # -- BINARIZING --
    show_exec mkdir -p ${bindir}
    show_exec ${BIN}/processPhraseTable -ttable 0 0 ${transdir}/model/phrase-table.gz -nscores 5 -out ${bindir}/phrase-table
    show_exec sed -e "s/PhraseDictionaryMemory/PhraseDictionaryBinary/" -e "s#${transdir}/model/phrase-table\.gz#${bindir}/phrase-table#" -e "s#${transdir}/model/reordering-table\.wbe-msd-bidirectional-fe\.gz#${bindir}/reordering-table#" ${workdir}/mert-work/moses.ini \> ${final_ini}
  elif [ "${decoder}" == "travatar" ]; then
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
      show_exec ${dir}/test.sh ${mt_method} ${task} ${final_ini} ${corpus}/test.true.{$lang_src,$lang_trg} tuned --threads=${THREADS}
      show_exec ${dir}/test.sh ${mt_method} ${task} ${final_ini} ${corpus}/dev.true.{$lang_src,$lang_trg} dev --threads=${THREADS}
    else
      show_exec ${dir}/filter.sh ${mt_method} ${final_ini} ${corpus}/test.true.${lang_src} ${workdir}/filtered
      show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${corpus}/test.true.{$lang_src,$lang_trg} tuned --threads=${THREADS}
      show_exec ${dir}/filter.sh ${mt_method} ${final_ini} ${corpus}/dev.true.${lang_src} ${workdir}/filtered
      show_exec ${dir}/test.sh ${mt_method} ${task} ${filtered_ini} ${corpus}/dev.true.{$lang_src,$lang_trg} dev --threads=${THREADS}
    fi
  fi
fi

#show_exec rm -rf ${workdir}/filtered
head ${workdir}/score*

echo "##### End of script: $0 $*"

