#!/bin/bash

dir=$(cd $(dirname $0); pwd)
output="nohup_hiero_$1-$3.out"
now=$(date +"%Y/%m/%d %H:%M:%S")

nohup nice time "$dir/train-hiero.sh" $* > ${output} &
echo "NOHUP_PID: $!, TASK: hiero_$1-$3, Date: ${now}, Host: ${HOSTNAME}, Args: $*" >> running.pid
tail -f $output

