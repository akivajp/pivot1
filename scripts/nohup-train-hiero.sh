#!/bin/bash

dir=$(cd $(dirname $0); pwd)
task="hiero_$1-$3"
output="nohup_${task}.out"
now=$(date +"%Y/%m/%d %H:%M:%S")

nohup nice time "$dir/train-hiero.sh" $* > ${output} &
echo "TASK: ${task}, Date: ${now}, Host: ${HOSTNAME}, NOHUP_PID: $!, Args: $*" >> running.pid
tail -f $output

