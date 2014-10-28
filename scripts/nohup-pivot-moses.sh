#!/bin/bash

dir=$(cd $(dirname $0); pwd)
if [ $# -lt 3 ]; then
  ${dir}/pivot-moses.sh $*
  exit 1
fi

task1=$1
task2=$2
trans1=${task1#*_}
trans2=${task2#*_}
lang1=${trans1%-*}
lang2=${trans1#*-}
lang3=${trans2#*-}
task="pivot_moses_${lang1}-${lang2}-${lang3}"
stamp=$(date +"%Y%m%d-%H%M%S")
now=$(date +"%Y/%m/%d %H:%M:%S")
output="nohup_${task}_$stamp.out"

touch ${output}
nohup nice time "$dir/pivot-moses.sh" $* > ${output} &
echo "TASK: ${task}, Date: ${now}, Host: ${HOSTNAME}, NOHUP_PID: $!, Args: $*" >> running.pid
tail -f $output

