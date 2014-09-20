#!/usr/bin/env python3
# encoding: utf-8

import inspect

debugging = True
builtin_print = print

def show_caller():
  s = inspect.stack()[2]
  frame    = s[0]
  filename = s[1]
  line     = s[2]
  name     = s[3]
  code     = s[4]
  if code:
    builtin_print("[%s:%s] %s: " % (filename, line, code[0].strip() ), end='')
  else:
    builtin_print("[%s:%s] : " % (filename, line), end='')

def print(*args, **keys):
  if debugging:
    show_caller()
    builtin_print(*args, **keys)

