#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

if [ ${#ARGS[@]} -ne 3 ]; then
  echo "usage: lang infile outfile" > /dev/stderr
  echo ""
  echo "--splitsize={int}"
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
  if [[ ! -f ${WORKDIR}/tmp/DONE.parse.${BASE} ]]; then
    if [[ ! -f ${WORKDIR}/tmp/START.parse.${BASE} ]]; then
      show_exec echo ${WORKID} \> ${WORKDIR}/tmp/START.parse.${BASE}
      show_exec sleep 1
      local TMPID=$(cat ${WORKDIR}/tmp/START.parse.${BASE})
      if [[ "${TMPID}" == "${WORKID}" ]]; then
        show_exec ${CKYLARK}/src/bin/ckylark --model ${MODEL} --input ${INFILE} --output ${WORKDIR}/tmp/${BASE}.parsed --add-root-tag
        show_exec echo ${WORKID} \> ${WORKDIR}/tmp/DONE.parse.${BASE}
      else
        echo "File exists: ${WORKDIR}/tmp/START.parse.${BASE}" $(cat ${WORKDIR}/tmp/START.parse.${BASE})
      fi
    else
      echo "File exists: ${WORKDIR}/tmp/START.parse.${BASE}" $(cat ${WORKDIR}/tmp/START.parse.${BASE})
    fi
  else
    echo "File exists: ${WORKDIR}/tmp/DONE.parse.${BASE}" $(cat ${WORKDIR}/tmp/DONE.parse.${BASE})
  fi
}

export -f check_parse
export -f show_exec
export SHELL=/bin/bash
export WORKDIR
export WORKID
export MODEL
export CKYLARK

WORKDIR=$(dirname $OUTFILE)
BASE=$(basename $INFILE)
WORKID="${HOST}:$$"
if [ ! -f ${WORKDIR}/DONE.parse.${BASE} ]; then
  if [[ ! -d ${WORKDIR}/tmp ]]; then
    show_exec mkdir -p ${WORKDIR}/tmp
  fi
  if [ ! -f ${WORKDIR}/tmp/DONE.split.${BASE} ]; then
    if [ -f ${WORKDIR}/tmp/START.split.${BASE} ]; then
      wait_file ${WORKDIR}/tmp/DONE.split.${BASE}
    else
      show_exec echo ${WORKID} \> ${WORKDIR}/tmp/START.split.${BASE}
      show_exec sleep 1
      TMPID=$(cat ${WORKDIR}/tmp/START.split.${BASE})
      if [[ "${TMPID}" == "${WORKID}" ]]; then
        show_exec split -a 4 -l ${SPLITSIZE} ${INFILE} ${WORKDIR}/tmp/${BASE}.
        for file in ${WORKDIR}/tmp/${BASE}.*; do
          show_exec mv ${file} ${file}.toparse
        done
        show_exec echo ${WORKID} \> ${WORKDIR}/tmp/DONE.split.${BASE}
      fi
    fi
  fi
#  show_exec ls ${WORKDIR}/tmp/${BASE}.\*.toparse \| parallel -j ${THREADS} check_parse {}
  show_exec find ${WORKDIR}/tmp \| grep -E '".toparse$"' \| parallel -j ${THREADS} check_parse {}
  if [ -f ${WORKDIR}/tmp/START.merge.${BASE} ]; then
    echo "File exists: ${WORKDIR}/tmp/START.merge.${BASE}" $(cat ${WORKDIR}/tmp/START.merge.${BASE})
    wait_file ${WORKDIR}/tmp/DONE.merge.${BASE}
  else
    show_exec echo ${WORKID} \> ${WORKDIR}/tmp/START.merge.${BASE}
    show_exec sleep 1
    TMPID=$(cat ${WORKDIR}/tmp/START.merge.${BASE})
    if [[ "${TMPID}" == "${WORKID}" ]]; then
      for file in ${WORKDIR}/tmp/${BASE}.*.toparse; do
        wait_file ${WORKDIR}/tmp/DONE.parse.$(basename $file .toparse)
      done
      show_exec cat ${WORKDIR}/tmp/${BASE}.\*.parsed \| pv -Wl \> ${OUTFILE}
      show_exec echo ${WORKID} \> ${WORKDIR}/tmp/DONE.merge.${BASE}
    fi
  fi
  #show_exec rm -rf ${WORKDIR}/tmp
  show_exec echo ${WORKID} \> ${WORKDIR}/DONE.parse.${BASE}
fi

