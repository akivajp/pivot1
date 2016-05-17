#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

if [ ${#ARGS[@]} -ne 3 ]; then
  echo "usage: lang infile outfile" > /dev/stderr
  echo ""
  echo "--splitsize={int}"
  echo "--tmp={dirname}"
  exit 1
fi

SRC=$1
INFILE=$2
OUTFILE=$3
SPLITSIZE=10000

case $SRC in
  en) MODEL=${CKYLARK}/data/wsj;;
  ja) MODEL=${CKYLARK}/data/jdc;;
  *)
    echo "language is not supported: $SRC" > /dev/stderr
    exit 1
    ;;
esac

if [ "${opt_splitsize}" ]; then
  SPLITSIZE=${opt_splitsize}
fi

wait_file() {
  local FILE=$1
  if [ ! -f "$FILE" ]; then
    echo "waiting for file: \"${FILE}\" ..."
  fi
  while [ ! -f "$FILE" ]; do
    sleep 1
  done
  echo "file exists: \"${FILE}\""
}

check_parse() {
  local INFILE=$1
  local BASE=$(basename $INFILE .toparse)
  if [[ ! -f ${TMPDIR}/DONE.parse.${BASE} ]]; then
    if [[ ! -f ${TMPDIR}/START.parse.${BASE} ]]; then
      show_exec echo ${WORKID} \> ${TMPDIR}/START.parse.${BASE}
      show_exec sleep 1
      local TMPID=$(cat ${TMPDIR}/START.parse.${BASE})
      if [[ "${TMPID}" == "${WORKID}" ]]; then
        show_exec ${CKYLARK}/src/bin/ckylark --model ${MODEL} --input ${INFILE} --output ${TMPDIR}/${BASE}.parsed --add-root-tag
        show_exec echo ${WORKID} \> ${TMPDIR}/DONE.parse.${BASE}
      else
        echo "File exists: ${TMPDIR}/START.parse.${BASE}" $(cat ${TMPDIR}/START.parse.${BASE})
      fi
    else
      echo "File exists: ${TMPDIR}/START.parse.${BASE}" $(cat ${TMPDIR}/START.parse.${BASE})
    fi
  else
    echo "File exists: ${TMPDIR}/DONE.parse.${BASE}" $(cat ${TMPDIR}/DONE.parse.${BASE})
  fi
}

export -f check_parse
export -f show_exec
export SHELL=/bin/bash
export WORKDIR
export WORKID
export MODEL
export CKYLARK
export TMPDIR

WORKDIR=$(dirname $OUTFILE)
BASE=$(basename $INFILE)
WORKID="${HOST}:$$"

TMPDIR=./tmp
if [ "${opt_tmp}" ]; then
  TMPDIR="${opt_tmp}"
fi

if [ ! -f ${WORKDIR}/DONE.parse.${BASE} ]; then
  if [[ ! -d ${TMPDIR} ]]; then
    show_exec mkdir -p ${TMPDIR}
  fi
  if [ ! -f ${TMPDIR}/DONE.split.${BASE} ]; then
    if [ -f ${TMPDIR}/START.split.${BASE} ]; then
      wait_file ${TMPDIR}/DONE.split.${BASE}
    else
      show_exec echo ${WORKID} \> ${TMPDIR}/START.split.${BASE}
      show_exec sleep 1
      TMPID=$(cat ${TMPDIR}/START.split.${BASE})
      if [[ "${TMPID}" == "${WORKID}" ]]; then
        show_exec split -a 4 -l ${SPLITSIZE} ${INFILE} ${TMPDIR}/${BASE}.
        for file in ${TMPDIR}/${BASE}.*; do
          show_exec mv ${file} ${file}.toparse
        done
        show_exec echo ${WORKID} \> ${TMPDIR}/DONE.split.${BASE}
      fi
    fi
  fi
#  show_exec ls ${TMPDIR}/${BASE}.\*.toparse \| parallel -j ${THREADS} check_parse {}
  show_exec find ${TMPDIR} \| grep -E '".toparse$"' \| parallel -j ${THREADS} check_parse {}
  if [ -f ${TMPDIR}/START.merge.${BASE} ]; then
    echo "File exists: ${TMPDIR}/START.merge.${BASE}" $(cat ${TMPDIR}/START.merge.${BASE})
    wait_file ${TMPDIR}/DONE.merge.${BASE}
  else
    show_exec echo ${WORKID} \> ${TMPDIR}/START.merge.${BASE}
    show_exec sleep 1
    TMPID=$(cat ${TMPDIR}/START.merge.${BASE})
    if [[ "${TMPID}" == "${WORKID}" ]]; then
      for file in ${TMPDIR}/${BASE}.*.toparse; do
        wait_file ${TMPDIR}/DONE.parse.$(basename $file .toparse)
      done
      show_exec cat ${TMPDIR}/${BASE}.\*.parsed \| pv -Wl \> ${OUTFILE}
      show_exec echo ${WORKID} \> ${TMPDIR}/DONE.merge.${BASE}
    fi
  fi
  #show_exec rm -rf ${TMPDIR}
  show_exec echo ${WORKID} \> ${WORKDIR}/DONE.parse.${BASE}
fi

