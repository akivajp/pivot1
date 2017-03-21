#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

usage()
{
  echo "usage: $0 mt_method task path/to/inifile input ref [test_name]"
  echo ""
  echo "options:"
  echo "  --threads={integer}"
  echo "  --trg_factors={integer}"
}

proc_args $*

if [ ${#ARGS[@]} -lt 5 ]
then
  usage
  exit 1
fi

mt_method=${ARGS[0]}
task=${ARGS[1]}
inifile=${ARGS[2]}
input=${ARGS[3]}
ref=${ARGS[4]}
test_name=${ARGS[5]}

workdir="${task}/working"

show_exec mkdir -p ${workdir}
if [ "${test_name}" ]; then
  output=${workdir}/translated-${test_name}.out
  trace=${workdir}/trace-${test_name}.out
  score=${workdir}/score-${test_name}.out
else
  output=${workdir}/translated.out
  trace=${workdir}/trace.out
fi

if [ "${mt_method}" == "pbmt" ]; then
#  show_exec ${MOSES}/bin/moses -f ${inifile} -threads ${THREADS} \< ${input} \> ${output}
  show_exec ${MOSES}/bin/moses -f ${inifile} -threads ${THREADS} \< ${input} \| tee ${output}
elif [ "${mt_method}" == "hiero" ]; then
  show_exec ${TRAVATAR}/src/bin/travatar -config_file ${inifile} -threads ${THREADS} -trace_out ${trace} -in_format word \< ${input} \| tee ${output}
elif [ "${mt_method}" == "t2s" ]; then
#  show_exec ${TRAVATAR}/src/bin/travatar -config_file ${inifile} -threads ${THREADS} \< ${input} \> ${output}
#  show_exec ${TRAVATAR}/src/bin/travatar -config_file ${inifile} -threads ${THREADS} \< ${input} \| tee ${output}
  show_exec ${TRAVATAR}/src/bin/travatar -config_file ${inifile} -threads ${THREADS} -trace_out ${trace} -in_format penn \< ${input} \| tee ${output}
elif [ "${mt_method}" == "f2s" ]; then
  show_exec ${TRAVATAR}/src/bin/travatar -config_file ${inifile} -threads ${THREADS} -trace_out ${trace} -in_format egret \< ${input} \| tee ${output}
else
  echo "Invalid MT method: ${mt_method}" > /dev/stderr
  exit 1
fi

if [ "${score}" ]; then
  if [ "${opt_trg_factors}" ]; then
      score=${workdir}/score-${test_name}0.out
      show_exec ${BIN}/mt-evaluator -eval "'bleu:factor=0 ribes:factor=0'" -ref ${ref} ${output} \| tee ${score}
#    for i in $(seq 0 1); do
#      score_i=${workdir}/score-${test_name}${i}.out
#      show_exec ${BIN}/mt-evaluator -eval "'bleu:factor=${i} ribes:factor=${i}'" -ref ${ref} ${output} \| tee ${score_i}
#    done
#  else
#    show_exec ${BIN}/mt-evaluator -ref ${ref} ${output} \> ${score}
#    cat ${score}
  else
    show_exec ${BIN}/mt-evaluator -ref ${ref} ${output} \| tee ${score}
  fi
else
  show_exec ${BIN}/mt-evaluator -ref ${ref} ${output}
fi

