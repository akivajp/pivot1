#!/bin/bash

dir=$(cd $(dirname $0); pwd)
output="nohup_hiero_$1-$3.out"

nohup nice time "$dir/train_hiero.sh" $* > ${output} &
echo "NOHUP_PID: $!, TASK: hiero_$1-$3, Date: $(date)" >> running.pid
tail -f $output

