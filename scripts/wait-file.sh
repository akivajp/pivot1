#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
source "${dir}/common.sh"

if [ $# -lt 1 ]; then
  echo "usage: $0 file [file ...]"
  exit 1
fi

wait_onefile()
{
  local STAMP=$(get_stamp)
  if [ ! -f "$FILE" ]; then
    echo "[log ${STAMP}] waiting for file: \"${FILE}\" ..."
  fi
  while [ ! -f "$FILE" ]; do
    sleep 1
  done
  echo "[log ${STAMP}] file exists: \"${FILE}\""
}

for FILE in $*; do
  wait_onefile ${FILE}
done

