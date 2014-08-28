#!/bin/bash

dir=$(cd $(dirname $0); pwd)
task="moses_$1-$3"
stamp=$(date +"%Y%m%d-%H%M%S")
now=$(date +"%Y/%m/%d %H:%M:%S")
output="nohup_${task}_$stamp.out"

touch ${output}
nohup nice time "$dir/train-moses.sh" $* > ${output} &
echo "TASK: ${task}, Date: ${now}, Host: ${HOSTNAME}, NOHUP_PID: $!, Args: $*" >> running.pid
tail -f $output

