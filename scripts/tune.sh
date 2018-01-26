#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

TUNE_NBEST=200
EVAL=bleu
MAX_ITERS=20

usage()
{
  echo "usage: $0 mt_method corpus1 corpus2 inifile task_dir [tune_name [alter_lm]]"
  echo ""
  echo "options:"
  echo "  --threads={integer}"
  echo "  --eval={string}"
  echo "  --max_iters={integer}"
}

if [ ${#ARGS[@]} -lt 5 ]
then
  usage
  exit 1
fi

mt_method=${ARGS[0]}
src1=$(abspath ${ARGS[1]})
src2=$(abspath ${ARGS[2]})
inifile=$(abspath ${ARGS[3]})
task=${ARGS[4]}
tune_name=${ARGS[5]}
alter_lm=${ARGS[6]}

if [ ${opt_threads} ]; then
  THREADS=${opt_threads}
fi

if [ ${opt_max_iters} ]; then
    MAX_ITERS=${opt_max_iters}
fi

mert_out="mert-work"
if [ "${tune_name}" ]; then
    mert_out="${mert_out}-${tune_name}"
fi
if [ "${opt_eval}" ]; then
  EVAL=${opt_eval}
  #mert_out="mert-work-${opt_eval}"
  mert_out="${mert_out}-${EVAL}"
fi

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
    trg_factors=$(grep -1 trg_factors $inifile | tail -n 1)
    if [ "${trg_factors}" ]; then
      options="-trg-factors ${trg_factors}"
      if [ ${trg_factors} -gt 1 ]; then
        EVAL="bleu:factor=0"
        if [ "${opt_eval}" ]; then
          EVAL="${opt_eval}:factor=0"
        fi
        if [ ! "${opt_max_iters}" ]; then
            MAX_ITERS=30
        fi
      fi
    fi
    if [ "${alter_lm}" ]; then
        abs_lm=$(abspath ${alter_lm})
        show_exec cat ${inifile} \| sed -e "'/\\[lm_file\\]/ { n; s#.*#${abs_lm}# }'" \> ${workdir}/travatar-${tune_name}.ini
        inifile=${workdir}/travatar-${tune_name}.ini

    fi
    #show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${inifile} -nbest ${TUNE_NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} -working-dir ${workdir}/${mert_out} -in-format word -threads ${THREADS} -eval ${EVAL} ${options} -resume
    show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${inifile} -nbest ${TUNE_NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} -working-dir ${workdir}/${mert_out} -in-format word -threads ${THREADS} -eval ${EVAL} -max-iters ${MAX_ITERS} ${options} -resume
    ;;
  t2s)
    show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${inifile} -nbest ${TUNE_NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} -working-dir ${workdir}/${mert_out} -in-format penn -threads ${THREADS} -eval ${EVAL} -resume
    ;;
  f2s)
    show_exec $TRAVATAR/script/mert/mert-travatar.pl -travatar-config ${inifile} -nbest ${TUNE_NBEST} -src ${src1} -ref ${src2} -travatar-dir ${TRAVATAR} -working-dir ${workdir}/${mert_out} -in-format egret -threads ${THREADS} -eval ${EVAL} -resume
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

if [ "${tune_name}" ]; then
    show_exec mkdir -p ${task}/${tune_name}
    cp ${workdir}/${mert_out}/travatar.ini ${task}/${tune_name}/
fi

