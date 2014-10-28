#!/bin/bash

dir=$(cd $(dirname $0); pwd)

if [ $# -lt 2 ]; then
  echo "usage: $0 path/to/original/rule-table.gz path/to/save/filtered/rule-table.gz"
  exit -1
fi

python ${dir}/filter-rule.py $1 'egfp < -4.5 & fgep < -4.5' 'egfp < -7' 'fgep < -7' 'egfl < -15' 'fgel < -15' | gzip > $2

