#!/bin/bash

dir=$(cd $(dirname $0); pwd)
if [ $# -lt 4 ]; then
  ${dir}/pivot-travatar.sh $*
  exit 1
fi

taskname1=$(basename $1)
taskname2=$(basename $2)
method=$(expr $taskname1 : '\(.*\)_..-..')
lang1=$(expr $taskname1 : '.*_\(..\)-..')
lang2=$(expr $taskname1 : '.*_..-\(..\)')
lang3=$(expr $taskname2 : '.*_..-\(..\)')
task="cascade_${method}_${lang1}-${lang2}-${lang3}"
stamp=$(date +"%Y%m%d-%H%M%S")
now=$(date +"%Y/%m/%d %H:%M:%S")
output="nohup_${task}_$stamp.out"

touch ${output}
nohup nice time "$dir/test-cascade.sh" $* > ${output} &
echo "TASK: ${task}, Date: ${now}, Host: ${HOSTNAME}, NOHUP_PID: $!, Args: $*" >> running.pid
tail -f $output

