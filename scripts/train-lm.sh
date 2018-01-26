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
  echo "  --ngram={integer}"
  echo "  --intermediate"
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

if [ "${opt_ngram}" ]; then
  ORDER=${opt_ngram}
fi

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
  #name="train"
  name="lm"
fi

if [ ! -d "${langdir}" ]; then
  show_exec mkdir -p $langdir
fi

if [ "${size}" ]; then
  #show_exec cat ${src} \| pv -Wl \| tail -n +${START} \|  head -n ${size} \| ${TRAVATAR}/src/kenlm/lm/lmplz -o ${ORDER} \| pv -Wl \> ${langdir}/${name}.arpa.${lang}
  if [ "${opt_intermediate}" ]; then
      show_exec cat ${src} \| pv -Wl \| tail -n +${START} \|  head -n ${size} \| ${KENLM}/lmplz -o ${ORDER} --intermediate ${name}.inter.${lang} --discount_fallback
  else
      show_exec cat ${src} \| pv -Wl \| tail -n +${START} \|  head -n ${size} \| ${KENLM}/lmplz -o ${ORDER} \| pv -Wl \> ${langdir}/${name}.arpa.${lang} --discount_fallback
  fi
else
  if [ "${opt_intermediate}" ]; then
    show_exec cat ${src} \| pv -Wl \| tail -n +${START} \| ${KENLM}/lmplz -o ${ORDER} --intermediate ${name}.inter.${lang} --discount_fallback
  else
    show_exec cat ${src} \| pv -Wl \| tail -n +${START} \| ${KENLM}/lmplz -o ${ORDER} \| pv -Wl \> ${langdir}/${name}.arpa.${lang} --discount_fallback
  fi
fi

# -- BINARISING --
#show_exec ${TRAVATAR}/src/kenlm/lm/build_binary -i ${langdir}/${name}.arpa.${lang} ${langdir}/${name}.blm.${lang}
if [ ! "${opt_intermediate}" ]; then
    show_exec ${KENLM}/build_binary -i ${langdir}/${name}.arpa.${lang} ${langdir}/${name}.blm.${lang}
fi

