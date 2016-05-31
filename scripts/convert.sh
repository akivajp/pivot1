#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

echo "running script with PID: $$"

usage()
{
  echo "usage: $0 mt_method lang_id1 lang_id2"
  echo ""
  echo "mt_method: {tp,sp,gp,xp}2{s,x}/{s,x}2{tp,sp,gp,xp}"
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
  tp2*)
    decoder=travatar
    src_test=${corpus}/src.${lang1}
    src_dev=${corpus}/src.${lang1}
    trg_test=${corpus}/test.tree.${lang1}
    trg_dev=${corpus}/dev.tree.${lang1}
    ;;
  sp2*|gp*|xp2*)
    decoder=travatar
    src_test=${corpus}/src.${lang1}
    src_dev=${corpus}/src.${lang1}
    trg_test=${corpus}/test.${lang1}
    trg_dev=${corpus}/dev.${lang1}
    ;;
  s2*|x2*)
    decoder=travatar
    src_test=${corpus}/src.${lang1}
    src_dev=${corpus}/src.${lang1}
    trg_test=${corpus}/test.${lang1}
    trg_dev=${corpus}/dev.${lang1}
    ;;
  *)
    echo "mt_methos should be one of {tp,sp,gp,xp}2{s,x} / {s,x}2{tp,sp,gp,xp}"
    exit 1
    ;;
esac

case ${decoder} in
  travatar)
    tunedir=${task}/tuned
    plain_ini=${transdir}/model/travatar.ini
    final_ini=${tunedir}/travatar.ini
    filtered_ini=${filterdir}/travatar.ini
    ;;
esac

case "${mt_method}" in
  ?p2*)
    BASE_TASK=t2s_${lang1}-${lang2}
    if [ ! -f "${BASE_TASK}/TM/model/travatar.ini" ]; then
      echo "[error] base task \"${BASE_TASK}\" is not trained" > /dev/stderr
      exit 1
    fi
    ;;
  *2?p)
    BASE_TASK=t2s_${lang2}-${lang1}
    if [ ! -f "${BASE_TASK}/TM/model/travatar.ini" ]; then
      echo "[error] base task \"${BASE_TASK}\" is not trained" > /dev/stderr
      exit 1
    fi
    ;;
  *)
    echo "Cannot resolve base task directory: ${mt_method}"
    exit 1
    ;;
esac

ask_continue ${task}

TM_FILE="${transdir}/model/rule-table.gz"
if [ ! -f ${plain_ini} ]; then
  SORT_OPTIONS="-S10%"
  RT_SRCTRG="${transdir}/model/rule-table.src-trg.gz";
  RT_TRGSRC="${transdir}/model/rule-table.trg-src.gz";
  PV_PIPE="pv -Wl";
  PV_SORT="pv -Wl -N 'Sorting Records'";
  SMOOTH="none"
  NBEST_RULES=20
  FOF_FILE="${transdir}/model/fof.txt"
  LEX_TRGSRC="${task}/TM/lex/trg_given_src.lex"
  LEX_SRCTRG="${task}/TM/lex/src_given_trg.lex"
  EXTRACT_FILE="${transdir}/model/extract.gz"
#  if [ "${lang1}" == "en" ]; then
#    EXTRACT_FILE_REV="${BASE_TASK}/TM/model/extract.gz"
#  elif [ "${lang2}" == "en" ]; then
#    EXTRACT_FILE_REV="${BASE_TASK}/TM/model/extract.gz"
#  fi

  if [ ! -d ${task} ]; then
    show_exec mkdir -p ${transdir}/model
    LOG=${task}/log
    echo "[$(get_stamp) ${HOST}] $0 $*" >> ${LOG}
    show_exec ln ${BASE_TASK}/TM/model/fof.txt ${transdir}/model/
  else
    LOG=${task}/log
  fi

  if [ ! -d ${task}/TM/lex ]; then
    show_exec mkdir -p ${task}/TM/lex
    if [[ "${mt_method}" =~ .p2. ]]; then
      show_exec ln ${BASE_TASK}/TM/lex/src_given_trg.lex ${task}/TM/lex/
      show_exec ln ${BASE_TASK}/TM/lex/trg_given_src.lex ${task}/TM/lex/
    elif [[ "${mt_method}" =~ .2.p ]]; then
      show_exec ln ${BASE_TASK}/TM/lex/src_given_trg.lex ${task}/TM/lex/trg_given_src.lex
      show_exec ln ${BASE_TASK}/TM/lex/trg_given_src.lex ${task}/TM/lex/src_given_trg.lex
      #show_exec "zcat ${EXTRACT_FILE_REV} | ${TRAVATAR}/script/train/reverse-rt.pl | ${PV_PIPE} | gzip > ${EXTRACT_FILE}"
    else
      echo "Error: ${mt_method} =~ .p2. or .2.p" > /dev/stderr
      exit 1
    fi
  fi

  if [[ "${mt_method}" =~ .p2. ]]; then
    if [[ ! -d ${task}/LM ]]; then
      show_exec mkdir -p ${task}/LM
      show_exec ln ${BASE_TASK}/LM/* ${task}/LM
    fi
  fi

  case "${mt_method}" in
    tp2s)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=scfg -p
      ;;
    tp2x)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=hiero -p
      ;;
    sp2s)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=scfg --flatten=scfg -p
      ;;
    sp2x)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=hiero --flatten=scfg -p
      ;;
    gp2s)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=scfg --flatten=tag -p
      ;;
    gp2x)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=hiero --flatten=tag -p
      ;;
    xp2s)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=scfg --flatten=hiero -p
      ;;
    xp2x)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=hiero --flatten=hiero -p
      ;;
    s2tp)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=scfg --reverse --no-unary -p
      ;;
    s2sp)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=scfg --flatten=scfg --reverse --no-unary -p
      ;;
    s2gp)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=scfg --flatten=tag --reverse --no-unary -p
      ;;
    s2xp)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=scfg --flatten=hiero --reverse --no-unary -p
      ;;
    x2tp)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=hiero --reverse --no-unary -p
      ;;
    x2sp)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=hiero --flatten=scfg --reverse --no-unary -p
      ;;
    x2gp)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=hiero --flatten=tag --reverse --no-unary -p
      ;;
    x2xp)
      show_exec PYTHONPATH=${PYTHONPATH} ${PYTHONPATH}/exp/ruletable/convert_extract.py ${BASE_TASK}/TM/model/extract.gz ${transdir}/model/extract.gz --sync=hiero --flatten=hiero --reverse --no-unary -p
      ;;
  esac

  show_exec "zcat $EXTRACT_FILE | env LC_ALL=C sort $SORT_OPTIONS | $TRAVATAR/script/train/score-t2s.pl --fof-file=$FOF_FILE --lex-prob-file=$LEX_TRGSRC --cond-prefix=egf --joint | env LC_ALL=C sort $SORT_OPTIONS | gzip > $RT_SRCTRG &";
  show_exec "zcat $EXTRACT_FILE | ${TRAVATAR}/script/train/reverse-rt.pl | $PV_SORT | env LC_ALL=C sort $SORT_OPTIONS | $TRAVATAR/script/train/score-t2s.pl --lex-prob-file=$LEX_SRCTRG --cond-prefix=fge | $TRAVATAR/script/train/reverse-rt.pl | $PV_SORT | env LC_ALL=C sort $SORT_OPTIONS | $PV_PIPE | gzip > $RT_TRGSRC";
  show_exec wait
  show_exec "$TRAVATAR/script/train/combine-rt.pl --fof-file=$FOF_FILE --smooth=$SMOOTH --top-n=$NBEST_RULES $RT_SRCTRG $RT_TRGSRC | $PV_PIPE | gzip > $TM_FILE"
  show_exec cat "${BASE_TASK}/TM/model/travatar.ini" \| sed -e "'s:${BASE_TASK}:${task}:g'" \> ${plain_ini}
fi

echo "##### End of script: $0 $*" | tee -a ${LOG}

