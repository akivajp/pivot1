#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import gzip
import re
import sys

def parseFeatures(strKeyVals):
  fields = strKeyVals.strip().split()
  dictKeyVals = {}
  for strKeyVal in fields:
    key, val = strKeyVal.strip().split('=')
    dictKeyVals[key] = float(val)
  return dictKeyVals

def getValue(features, strKey):
  if strKey in ['egfp', 'fgep', 'egfl', 'fgel']:
    return float(features[strKey])
  return float(strKey)

def matchRule(features, rule):
  relations = rule.split('&')
  for relation in relations:
    m = re.match('(.*) (.*) (.*)', relation.strip())
    if m:
      (left, op, right) = m.groups()
      left = getValue(features, left)
      right = getValue(features, right)
      if not eval('%(left)s %(op)s %(right)s' % locals()):
        return False
  return True

def filterRule(path, rules):
  fobj = gzip.open(path, 'r')
  for line in fobj:
    line = line.strip()
    fields = line.split('|||')
    features = parseFeatures( fields[2] )
    #print(dictKeyVals)
    for rule in rules:
      if matchRule(features, rule):
        #print("SKIP: " + line)
        break
    else:
      pass
      print(line)

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description = "filter the rule table records with given parameters")
  parser.add_argument('path', type=str, help = "path to the Travatar rule-table")
  parser.add_argument('rules', type=str, help = '"{egfp|fgep|egfl|fgel} {>=|>|<|<=} {float} [& ...]"',
                      metavar = 'rule', nargs = '+')

  args = vars( parser.parse_args() )
  #print(args)
  filterRule(**args)

