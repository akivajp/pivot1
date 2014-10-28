#!/bin/bash

dir=$(cd $(dirname $0); pwd)
if [ $# -lt 2 ]; then
  ${dir}/train-hiero.sh $*
  exit 1
fi

task="hiero_$1-$2"
stamp=$(date +"%Y%m%d-%H%M%S")
now=$(date +"%Y/%m/%d %H:%M:%S")
output="nohup_${task}_$stamp.out"

touch ${output}
nohup nice time "$dir/train-hiero.sh" $* > ${output} &
echo "TASK: ${task}, Date: ${now}, Host: ${HOSTNAME}, NOHUP_PID: $!, Args: $*" >> running.pid
tail -f $output

