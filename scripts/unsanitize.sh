#!/bin/bash

if [ $# -lt 1 ]; then
  echo "usage: $0 filepath"
  exit 1
fi

sed -e "s/&amp;/\&/" -e "s/&lt;/</" -e "s/&gt;/>/" $1

