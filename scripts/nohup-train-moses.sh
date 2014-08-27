#!/bin/bash

dir=$(cd $(dirname $0); pwd)
task="moses_$1-$3"
output="nohup_${task}.out"
now=$(date +"%Y/%m/%d %H:%M:%S")

nohup nice time "$dir/train-moses.sh" $* > ${output} &
echo "TASK: ${task}, Date: ${now}, Host: ${HOSTNAME}, NOHUP_PID: $!, Args: $*" >> running.pid
tail -f $output

