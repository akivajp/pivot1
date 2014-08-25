#!/bin/bash

dir=$(cd $(dirname $0); pwd)
output="nohup_moses_$1-$3.out"
now=$(date +"%Y/%m/%d %H:%M:%S")

nohup nice time "$dir/train_moses.sh" $* > ${output} &
echo "NOHUP_PID: $!, TASK: moses_$1-$3, Date: ${now}, Host: ${HOSTNAME}, Args: $*" >> running.pid
ail -f $output

