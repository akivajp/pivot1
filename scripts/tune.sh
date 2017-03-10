#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

TUNE_NBEST=200
EVAL=bleu

usage()
{
  echo "usage: $0 mt_method corpus1 corpus2 inifile task_dir"
  echo ""
  echo "options:"
  echo "  --threads={integer}"
  echo "  --eval={string}"
}

if [ ${#ARGS[@]} -lt 5 ]
then
  usage
  exit 1
fi

if [ ${opt_threads} ]; then
  THREADS=${opt_threads}
fi

mert_out="mert-work"
if [ "${opt_eval}" ]; then
  EVAL=${opt_eval}
  mert_out="mert-work-${opt_eval}"
fi

mt_method=${ARGS[0]}
src1=$(abspath ${ARGS[1]})
src2=$(abspath ${ARGS[2]})
inifile=$(abspath ${ARGS[3]})
task=${ARGS[4]}

workdir="${task}/working"
show_exec mkdir -p ${workdir}
case "${mt_method}" in
  pbmt)
    task=$(abspath $task)
    show_exec pushd ${workdir}
    show_exec $MOSES/scripts/training/mert-moses.pl ${src1} ${src2} ${BIN}/moses ${inifile} --mertdir $MOSES/bin --threads ${THREADS} 2\> mert.out \| tee mert.log
    show_exec popd
    ;;
  hiero|scfg)
    options=""
    trg_factors=$(grep -1 trg_factors $inifile | tail -n1)
    if [ "${trg_factors}" ]; then
      options="-trg-factors ${trg_factors}"
      if [ ${trg_factors} -gt 1 ]; then
        EVAL="bleu:factor=0"
        if [ "${opt_eval}" ]; then
          EVAL="${opt_eval}:factor=0"
        fi
      fi
    fi
    show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${inifile} -nbest ${TUNE_NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} -working-dir ${workdir}/${mert_out} -in-format word -threads ${THREADS} -eval ${EVAL} ${options} -resume
    ;;
  t2s)
    show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${inifile} -nbest ${TUNE_NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} -working-dir ${workdir}/${mert_out} -in-format penn -threads ${THREADS} -eval ${EVAL} -resume
    ;;
  s2s)
    show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${inifile} -nbest ${TUNE_NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} -working-dir ${workdir}/${mert_out} -in-format word -threads ${THREADS} -eval ${EVAL} -resume
    ;;
  x2x)
    show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${inifile} -nbest ${TUNE_NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} -working-dir ${workdir}/${mert_out} -in-format word -threads ${THREADS} -eval ${EVAL} -resume
    ;;
esac

show_exec rm -rf ${workdir}/${mert_out}/filtered
if [[ "${mt_method}" == pbmt ]]; then
  show_exec rm ${workdir}/${mert_out}/*.gz
else
  show_exec rm ${workdir}/${mert_out}/*.nbest
  show_exec rm ${workdir}/${mert_out}/*.stats
  show_exec rm ${workdir}/${mert_out}/*.uniq
fi

