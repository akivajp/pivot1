#!/usr/bin/env python3

import sys

builtin_print = print

def clean(n = 1):
  if n > 0:
    sys.stdout.write(' ' * n + "\b" * n)

last_pos = [0]
def print(*args, **keys):
  sys.stdout.write("\r")
  count = sys.stdout.write( str.join(' ', map(str, args)) )
  clean( (last_pos[0] - count) * 2 )
  last_pos[0] = count
  sys.stdout.flush()

