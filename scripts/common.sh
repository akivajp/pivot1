#!/bin/bash

CKYLARK=$HOME/exp/ckylark

KYTEA=/home/is/akiba-mi/usr/local/bin/kytea
KYTEA_ZH_DIC=/home/is/akiba-mi/usr/local/share/kytea/lcmc-0.4.0-1.mod

IRSTLM=~/exp/irstlm
GIZA=~/usr/local/bin
TRAVATAR=$HOME/exp/travatar
BIN=$HOME/usr/local/bin

#THREADS=10
THREADS=4

dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
stamp=$(date +"%Y/%m/%d %H:%M:%S")

#echo "running script with PID: $$"

show_exec()
{
  echo "[exec] $*"
  eval $*

  if [ $? -gt 0 ]
  then
    echo "[error on exec]: $*"
    exit 1
  fi
}

proc_args()
{
  ARGS=()
  OPTS=()

  while [ $# -gt 0 ]
  do
    arg=$1
    case $arg in
      --*=* )
        opt=${arg#--}
        name=${opt%=*}
        var=${opt#*=}
        eval "opt_${name}=${var}"
        ;;
      --* )
        name=${arg#--}
        eval "opt_${name}=1"
        ;;
      -* )
        OPTS+=($arg)
        ;;
      * )
        ARGS+=($arg)
        ;;
    esac

    shift
  done
}

abspath()
{
  echo $(cd $(dirname $1) && pwd)/$(basename $1)
}

proc_args $*

if [ $opt_threads ]; then
  THREADS=${opt_threads}
fi

