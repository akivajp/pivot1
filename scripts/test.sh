#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

usage()
{
  echo "usage: $0 mt_method task path/to/inifile input ref [test_name]"
  echo ""
  echo "options:"
  echo "  --threads={integer}"
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
  score=${workdir}/score-${test_name}.out
else
  output=${workdir}/translated.out
fi

if [ "${mt_method}" == "pbmt" ]; then
#  show_exec ${MOSES}/bin/moses -f ${inifile} -threads ${THREADS} \< ${input} \> ${output}
  show_exec ${MOSES}/bin/moses -f ${inifile} -threads ${THREADS} \< ${input} \| tee ${output}
else
#  show_exec ${TRAVATAR}/src/bin/travatar -config_file ${inifile} -threads ${THREADS} \< ${input} \> ${output}
  show_exec ${TRAVATAR}/src/bin/travatar -config_file ${inifile} -threads ${THREADS} \< ${input} \| tee ${output}
fi

if [ "${score}" ]; then
  show_exec ${BIN}/mt-evaluator -ref ${ref} ${output} \> ${score}
  cat ${score}
else
  show_exec ${BIN}/mt-evaluator -ref ${ref} ${output}
fi

