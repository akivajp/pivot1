#!/usr/bin/env python3
# encoding: utf-8

import gzip
import os
import progress
import re
import sqlite3
import sys

import debug

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

def make_indices(db, table_name):
  db.execute('CREATE INDEX %(table_name)s_source ON %(table_name)s(source)' % locals() )
  db.execute('CREATE INDEX %(table_name)s_target ON %(table_name)s(target)' % locals() )
  db.execute('CREATE UNIQUE INDEX %(table_name)s_both ON %(table_name)s(source, target)' % locals() )

def insert_record(db, table_name, source, target, scores, align, counts):
  db.execute('''
    INSERT INTO %(table_name)s VALUES (
      null,
      "%(source)s",
      "%(target)s",
      "%(scores)s",
      "%(align)s",
      "%(counts)s"
    );
  ''' % locals() )

def get_pivot_count(db, table1, table2):
  cur = db.execute('''
    SELECT COUNT(*) FROM %(table1)s INNER JOIN %(table2)s ON %(table1)s.target = %(table2)s.source
  ''' % locals() )
  row = cur.fetchone()
  return row[0]

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

def gcd(a, b):
  if a > b:
    return gcd(b, a)
  if b % a == 0:
    return a
  else:
    return gcd(b % a, a)

def pivot(dbfile, table1, table2, savefile):
  if not os.path.isfile(dbfile):
    print("sqlite3 db file %s not exists", file=sys.stderr)
    sys.exit(2)
  db = sqlite3.connect(dbfile)
  if os.path.isfile(savefile):
    os.remove(savefile)
  #size = get_pivot_count(db, table1, table2)
  #debug.print(size)
  cur = select_pivot(db, table1, table2)
  # 周辺化を行う対象フレーズ
  # curr_phrase -> pivot_phrase -> target の形の訳出を探す
  curr_phrase = ''
  pivot_records = {}
  count = 0
  for row in cur:
    #print(row)
    count += 1
    source = row[0]
    pivot_phrase = row[1] # 参考までに取得しているが使わない
    target = row[2]
    scores1 = [float(score) for score in row[3].split(' ')]
    scores2 = [float(score) for score in row[4].split(' ')]
    align1 = row[5].split(' ')
    align2 = row[6].split(' ')
    counts1 = [int(count) for count in row[7].split(' ')]
    counts2 = [int(count) for count in row[8].split(' ')]
    if count % 10000 == 0:
      progress.print("pivoted %(count)d records, current phrase: '%(source)s'" % locals())
      pass
    if curr_phrase != source:
      # 新しい原言語フレーズが出てきたので、前のフレーズに対する周辺化を終えて書き出す
      write_records(savefile, curr_phrase, pivot_records)
      # 対象フレーズとレコードを新しくする
      curr_phrase = source
      pivot_records = {}
      #print("pivoting for '%s'" % curr_phrase)
    if not target in pivot_records:
      # 対象言語の訳出のレコードがまだ無いので作る
      pivot_records[target] = [ [0, 0, 0, 0], {}, [0, 0, 0] ]
    record = pivot_records[target]
    # 訳出のスコア(条件付き確率)を掛けあわせて加算する
    add_scores(record, scores1, scores2)
    # アラインメントのマージ
    merge_alignment(record, align1, align2)
  # 最後の書き出し
  progress.print("finished pivoting %(count)d records'" % locals())
  print()
  write_records(savefile, curr_phrase, pivot_records)


if __name__ == '__main__':
  if len(sys.argv) < 5:
    usage()
  dbfile = sys.argv[1]
  table1 = sys.argv[2]
  table2 = sys.argv[3]
  savefile = sys.argv[4]
  pivot(dbfile, table1, table2, savefile)

