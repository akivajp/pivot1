#!/bin/bash

dir=$(cd $(dirname $0); pwd)
output="nohup_moses_$1-$3.out"

nohup nice time "$dir/train_moses.sh" $* > ${output} &
echo "NOHUP_PID: $!, TASK: moses_$1-$3, Date: $(date)" >> running.pid
tail -f $output

