#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-

import argparse
import commands
import codecs
import os
import random
import sys
from subprocess import Popen, PIPE, call

PV = ""
if call('which pv > /dev/null', shell=True) == 0:
    PV = 'pv'

pv = [None]
def pv_reset(name, size):
    if pv[0]:
        pv[0].stdin.close()
        pv[0] = None
    if PV:
        cmd = "%s -Wl -N '%s' -s %s > /dev/null" % (PV, name, size)
        pv[0] = Popen(cmd, shell=True, stdin=PIPE)

def pv_incr():
    if PV:
        if not pv[0]:
            cmd = "%s -Wl > /dev/null" % (PV, name, size)
            pv[0] = Popen(cmd, shell=True, stdin=PIPE)
        pv[0].stdin.write("\n")
        pv[0].stdin.flush()

def pv_close():
    if pv[0]:
        pv[0].stdin.close()
        pv[0] = None

#def rfill(array, size, filling = 1):
#    zero_indices = []
#    pv_reset("zero counting", len(array))
#    for i,val in enumerate(array):
#        pv_incr()
#        if val == 0:
#            zero_indices.append(i)
#    if size > len(zero_indices):
#        sys.stderr.write("Error: rfill size = %s > %s = zero count\n" % (size,len(zero_indices)))
#        sys.exit(1)
#    pv_reset("randomize", size)
#    while size > 0:
#        rand = int(len(zero_indices) * random.random())
#        if 0 <= rand and rand < len(zero_indices):
#            index = zero_indices[rand]
#            array[index] = filling
#            zero_indices.pop(rand)
#            size -= 1
#            pv_incr()
#    return array

def rsplit(args):
    if not os.path.isfile(args.src_file):
        sys.stderr.write("File not exists: %s\n" % args.src_file)
        sys.exit(1)
    #num_lines = commands.getoutput('cat %s | wc -l' % args.src_file)
    #num_lines = int(num_lines)
    total = args.train_size + args.test_size + args.dev_size
    #if total > num_lines:
    #    sys.stderr.write("Error: %s+%s+%s > %s = line count\n" % (args.train_size,args.test_size,args.dev_size,num_lines))
    #    sys.exit(1)
    if args.seed != None:
        random.seed(args.seed)
    sys.stderr.write("Building sequence\n")
    pattern = [1]*args.train_size + [2]*args.test_size + [3]*args.dev_size
    sys.stderr.write("Randomizing sequence\n")
    random.shuffle(pattern)
    #pattern = rfill([0] * total, args.train_size, 1)
    #print(pattern)
    #rfill(pattern, args.test_size, 2)
    #print(pattern)
    if args.train_output[-1] != '.':
        args.train_output = args.train_output + '.'
    if args.test_output[-1] != '.':
        args.test_output = args.test_output + '.'
    if args.dev_output[-1] != '.':
        args.dev_output = args.dev_output + '.'
    in_src = open(args.src_file)
    in_trg = open(args.trg_file)
    out_train_src = open(args.train_output + args.lang_src, 'w')
    out_train_trg = open(args.train_output + args.lang_trg, 'w')
    out_test_src  = open(args.test_output + args.lang_src, 'w')
    out_test_trg  = open(args.test_output + args.lang_trg, 'w')
    out_dev_src   = open(args.dev_output + args.lang_src, 'w')
    out_dev_trg   = open(args.dev_output + args.lang_trg, 'w')
    pv_reset("lines", total)
    for i, lines in enumerate(zip(in_src,in_trg)):
        pv_incr()
        if i >= len(pattern):
            break
        if pattern[i] == 1:
            out_train_src.write(lines[0])
            out_train_trg.write(lines[1])
        elif pattern[i] == 2:
            out_test_src.write(lines[0])
            out_test_trg.write(lines[1])
        else:
            out_dev_src.write(lines[0])
            out_dev_trg.write(lines[1])
    pv_close()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('src_file')
    parser.add_argument('trg_file')
    parser.add_argument('train_size', type=int)
    parser.add_argument('test_size', type=int)
    parser.add_argument('dev_size', type=int)
    parser.add_argument('train_output')
    parser.add_argument('test_output')
    parser.add_argument('dev_output')
    parser.add_argument('lang_src')
    parser.add_argument('lang_trg')
    parser.add_argument('--seed', '-s', help='random seed', type=int)
    args = parser.parse_args()
    #print(args)
    rsplit(args)

if __name__ == '__main__':
    main()

