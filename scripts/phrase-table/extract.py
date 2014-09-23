#!/usr/bin/env python3
# encoding: utf-8

import argparse
import gzip
import multiprocessing
import os
import re
import sqlite3
import sys
import time

# local libs
import debug
import progress

IGNORE = 1e-3

def create_table(db, table_name):
  db.execute('''
    CREATE TABLE IF NOT EXISTS %(table_name)s (
      id integer primary key,
      source text,
      target text,
      scores text,
      alignment text,
      counts text
    )
  ''' % locals() )

def create_indices(db, table_name):
  db.execute('CREATE INDEX %(table_name)s_source ON %(table_name)s(source)' % locals() )
  db.execute('CREATE INDEX %(table_name)s_target ON %(table_name)s(target)' % locals() )
  db.execute('CREATE UNIQUE INDEX %(table_name)s_both ON %(table_name)s(source, target)' % locals() )

class Counter:
  def __init__(self):
    self.count = 0
    self.threshold = 1
    self.unit = 1

  def add(self, count = 1):
    self.count += count

  def should_print(self):
    '''プログレスを表示すべきかどうか

    しきい値が増加単位の100倍を超えると、増加単位が10倍になる'''
    if self.count < self.threshold:
      return False
    else:
      if self.threshold >= self.unit * 100:
        self.unit *= 10
      self.threshold += self.unit
      return True

def select_sorted(db, table):
  return db.execute('''
    SELECT source, target, scores, alignment, counts
      FROM %(table)s
      ORDER BY source, target
  ''' % locals() )

def extract(dbfile, table, savefile):
  if not os.path.isfile(dbfile):
    print('file %(dbfile)s does not exist' % dbfile)
    sys.exit(2)

  db = sqlite3.connect(dbfile)
  rows = select_sorted(db, table)

  if re.match('.*\.gz', savefile):
    f_out = gzip.open(savefile, 'w')
  else:
    f_out = open(savefile, 'w')
  count = Counter()
  for row in rows:
    count.add()
    source = row[0]
    rec  = row[0] + ' ||| '
    rec += row[1] + ' ||| '
    rec += row[2] + ' ||| '
    rec += row[3] + ' |||'
    # 出現頻度の推定も行いたいが非常に困難
    #rec += str.join(' ', map(str, record[2])) + ' |||'
    rec += "\n"
    if re.match('.*\.gz', savefile):
      f_out.write(bytes(rec, 'utf-8'))
    else:
      f_out.write(rec)
    if count.should_print():
      progress.print("saved %d records, last phrase: '%s'" % (count.count, source))
  f_out.close()
  progress.print('saved %d records' % (count.count) )
  print()

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description = 'load phrase tables from sqlite3 and extract into moses phrase table format')
  parser.add_argument('dbfile', help = 'sqlite3 dbfile including pivoted phrase table')
  parser.add_argument('table', help = 'table name of pivoted phrase table')
  parser.add_argument('savefile', help = 'path for saving moses phrase table file')

  args = vars(parser.parse_args())
  extract(**args)

