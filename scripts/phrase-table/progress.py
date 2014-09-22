#!/usr/bin/env python3

import sys

builtin_print = print

def clean(n = 30):
  builtin_print(' ' * n + "\b" * n, end = '')

def print(*args, **keys):
  builtin_print("\r", end='')
  builtin_print(*args, end='', **keys)
  clean()
  sys.stdout.flush()

