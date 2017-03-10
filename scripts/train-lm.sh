#!/bin/bash

ORDER=5

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

usage()
{
  echo "usage: $0 lang_id src_corpus [name] [size]"

  echo "options:"
  echo "  --task_name={string}"
  echo "  --here"
  echo "  --skip={integer}"
}

if [ ${#ARGS[@]} -lt 2 ]
then
  usage
  exit 1
fi

lang=${ARGS[0]}
src=${ARGS[1]}
name=${ARGS[2]}
size=${ARGS[3]}

let START=1
if [ $opt_skip ]; then
  let START="${opt_skip}"+1
fi

if [ $opt_task_name ]; then
  langdir="${opt_task_name}/LM_${lang}"
elif [ $opt_here ]; then
  langdir="."
else
  langdir=LM_${lang}
fi

if [ "${name}" ]; then
  name=${name}
else
  name="train"
fi

if [ ! -d "${langdir}" ]; then
  show_exec mkdir -p $langdir
fi

if [ "${size}" ]; then
  show_exec cat ${src} \| tail -n +${START} \|  head -n ${size} \| ${BIN}/lmplz -o ${ORDER} \> ${langdir}/${name}.arpa.${lang}
else
#  show_exec ${BIN}/lmplz -o ${ORDER} \< ${src} \> ${langdir}/${name}.arpa.${lang}
  show_exec cat ${src} \| tail -n +${START} \| ${BIN}/lmplz -o ${ORDER} \< ${src} \> ${langdir}/${name}.arpa.${lang}
fi

# -- BINARISING --
show_exec ${BIN}/build_binary -i ${langdir}/${name}.arpa.${lang} ${langdir}/${name}.blm.${lang}

