#!/usr/bin/env python3

builtin_print = print

def clean(n = 20):
  builtin_print(' ' * n + "\b" * n, end = '')

def print(*args, **keys):
  builtin_print("\r", end='')
  builtin_print(*args, end='', **keys)
  clean(20)

