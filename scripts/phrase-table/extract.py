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

def usage():
  print("usage: %s dbfile table1 table2 dest-phrase-table" % sys.argv[0])
  sys.exit(1)

def drop_table(db, table_name):
  db.execute('''
    DROP TABLE IF EXISTS %(table_name)s
  ''' % locals() )

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

def select_pivot(db, table1, table2):
  return db.execute('''
    SELECT %(table1)s.source, %(table1)s.target, %(table2)s.target, %(table1)s.scores, %(table2)s.scores,
           %(table1)s.alignment, %(table2)s.alignment, %(table1)s.counts, %(table2)s.counts
      FROM %(table1)s INNER JOIN %(table2)s ON %(table1)s.target = %(table2)s.source
  ''' % locals() )

def write_records(savefile, source, records):
  if re.match('.*\.gz', savefile):
    f_out = gzip.open(savefile, 'a')
  else:
    f_out = open(savefile, 'a')
  for target, record in records.items():
    rec  = source + ' ||| '
    rec += target + ' ||| '
    rec += str.join(' ', map(str, record[0])) + ' ||| '
    rec += str.join(' ', sorted(record[1].keys()) ) + ' |||'
    # 出現頻度の推定も行いたいが非常に困難
    #rec += str.join(' ', map(str, record[2])) + ' |||'
    rec += "\n"
    if re.match('.*\.gz', savefile):
      f_out.write(bytes(rec, 'utf-8'))
    else:
      f_out.write(rec)
  f_out.close()


def insert_records(db, table_name, records):
  for (source, target), record in records.items():
    scores = str.join(' ', map(str, record[0]) )
    align  = str.join(' ', sorted(record[1].keys()) )
    # 出現頻度の推定も行いたいが非常に困難
    counts = None
    #if True or target == '、':
    #  print("inserting source: '%(source)s', target: '%(target)s'" % locals())
    try:
      db.execute('''
        INSERT INTO %(table_name)s VALUES (
          null,
          "%(source)s",
          "%(target)s",
          "%(scores)s",
          "%(align)s",
          null
        );
      ''' % locals() )
    except:
      print("ERROR source: '%(source)s', target: '%(target)s'" % locals())
      sys.exit(3)
  #db.commit()


# スコアを掛けあわせて累積値に加算する
def add_scores(record, scores1, scores2):
  scores = record[0]
  for i in range(0, len(scores)):
    scores[i] += scores1[i] * scores2[i]

# アラインメントのマージを試みる
def merge_alignment(record, align1, align2):
  align = record[1]
  a1 = {}
  for pair in align1:
    (left, right) = pair.split('-')
    if not left in a1:
      a1[left] = []
    a1[left].append(right)
  a2 = {}
  for pair in align2:
    (left, right) = pair.split('-')
    if not left in a2:
      a2[left] = []
    a2[left].append(right)
  for left in a1.keys():
    for middle in a1[left]:
      if middle in a2:
        for right in a2[middle]:
          pair = '%(left)s-%(right)s' % locals()
          align[pair] = True
#  if align != {'0-0': True}:
#    debug.print(align1, align2)
#    debug.print(a1, a2)
#    debug.print(align)

def empty_all(queues):
  for q in queues:
    #debug.print(q, q.empty())
    if not q.empty():
      return False
  return True

def get_empty_queue(queues):
  for q in queues:
    if q.empty():
      return q
  else:
    return None

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
      progress.print('saved %d records, last phrase: %s' % (count.count, source))
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

