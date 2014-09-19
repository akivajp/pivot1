#!/bin/bash

#MOSES=/home/is/akiba-mi/exp/moses
#IRSTLM=~/exp/irstlm
#LMPLZ=$HOME/usr/local/bin/lmplz
BIN=$HOME/usr/local/bin

dir=$(cd $(dirname $0); pwd)

ORDER=5

usage()
{
  echo "usage: $0 lang_id src_corpus"

  echo "options:"
  echo "  --task_name={string}"
}

show_exec()
{
  echo "[exec] $*"
  eval $*

  if [ $? -gt 0 ]
  then
    echo "[error on exec]: $*"
    exit 1
  fi
}

proc_args()
{
  ARGS=()
  OPTS=()

  while [ $# -gt 0 ]
  do
    arg=$1
    case $arg in
      --*=* )
        opt=${arg#--}
        name=${opt%=*}
        var=${opt#*=}
        eval "opt_${name}=${var}"
        ;;
      -* )
        OPTS+=($arg)
        ;;
      * )
        ARGS+=($arg)
        ;;
    esac

    shift
  done
}

proc_args $*

if [ ${#ARGS[@]} -lt 2 ]
then
  usage
  exit 1
fi

lang=${ARGS[0]}
src=${ARGS[1]}

if [ $opt_task_name ]; then
  langdir="${opt_task_name}/LM_${lang}"
else
  langdir=LM_${lang}
fi
show_exec mkdir -p $langdir
#show_exec $IRSTLM/bin/add-start-end.sh \< ${src} \> ${langdir}/train.sb.${lang}
#show_exec $IRSTLM/bin/build-lm.sh -i ${langdir}/train.sb.${lang} -p -s improved-kneser-ney -o ${langdir}/train.lm.${lang}
#show_exec $IRSTLM/bin/compile-lm --text ${langdir}/train.lm.${lang}.gz ${langdir}/train.arpa.${lang}

show_exec ${BIN}/lmplz -o ${ORDER} \< ${src} \> ${langdir}/train.arpa.${lang}

# -- BINARISING --
show_exec ${BIN}/build_binary -i ${langdir}/train.arpa.${lang} ${langdir}/train.blm.${lang}

