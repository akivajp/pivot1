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
#SCALEUP = 100
SCALEUP = 1000

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

def insert_records(db, table_name, records):
  for (source, target), record in records.items():
    scores = str.join(' ', map(str, record[0]) )
    align  = str.join(' ', sorted(record[1].keys()) )
    # 出現頻度の推定も行いたいが非常に困難
    counts = None
    #if True or target == '、':
    #  print("inserting source: '%(source)s', target: '%(target)s'" % locals())
    sql = '''
      INSERT INTO %(table_name)s VALUES (
        null,
        ?,
        ?,
        "%(scores)s",
        "%(align)s",
        null
      );
    ''' % locals()
    db.execute(sql, (source, target) )
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

def get_empty_queue(procs, queues):
  for i, p in enumerate(procs):
    if not p.is_alive():
      sys.stderr.write("\n[error] Process %(i)d was terminated\n" % locals() )
      terminate_all(procs)
      sys.exit(3)
    q = queues[i]
    if q.empty():
      return q
  else:
    return None

def terminate_all(procs):
  print("terminating all the worker processes")
  for p in procs:
    p.terminate()
    p.join()

class Counter:
  def __init__(self):
    self.row_count = 0
    self.pivot_count = 0
    self.threshold = 1
    self.unit = 1

  def add_row_count(self, count = 1):
    self.row_count += count

  def add_pivot_count(self, count):
    self.pivot_count += count

  def should_print(self):
    '''プログレスを表示すべきかどうか

    しきい値が増加単位のSCALEUP倍を超えると、増加単位が10倍になる'''
    if self.pivot_count < self.threshold:
      return False
    else:
      if self.threshold >= self.unit * SCALEUP:
        self.unit *= 10
      self.threshold += self.unit
      return True

  def print(self, source = None):
    if source:
      if self.should_print():
        progress.print("processing %d records, pivoted %d records, last phrase: '%s'" %
                       (self.row_count, self.pivot_count, source))
    else:
      progress.print("processed %d records, pivoted %d records" % (self.row_count, self.pivot_count))
      print()

# ピボット対象のレコードの配列を record_queue で受け取り、処理したデータを pivot_queue で渡す
def proc(record_queue, pivot_queue):
  while True:
    if not record_queue.empty():
      # 処理すべきレコード配列を発見
      rows = record_queue.get()
      #debug.print(len(rows))

      records = {}
      source = ''
      for row in rows:
        #print(row)
        source = row[0]
        pivot_phrase = row[1] # 参考までに取得しているが使わない
        target = row[2]
        scores1 = [float(score) for score in row[3].split(' ')]
        scores2 = [float(score) for score in row[4].split(' ')]
        align1 = row[5].split(' ')
        align2 = row[6].split(' ')
        counts1 = [int(count) for count in row[7].split(' ')]
        counts2 = [int(count) for count in row[8].split(' ')]
        if not (source, target) in records:
          # 対象言語の訳出のレコードがまだ無いので作る
          records[(source, target)] = [ [0, 0, 0, 0], {}, [0, 0, 0] ]
        record = records[(source, target)]
        # 訳出のスコア(条件付き確率)を掛けあわせて加算する
        add_scores(record, scores1, scores2)
        # アラインメントのマージ
        merge_alignment(record, align1, align2)
      # 非常に小さな翻訳確率のフレーズは無視する
      ignoring = []
      for (source, target), rec in records.items():
        if rec[0][0] < IGNORE and rec[0][2] < IGNORE:
          #print("ignoring '%(source)s' -> '%(target)s' %(rec)s" % locals())
          ignoring.append( (source, target) )
        elif rec[0][0] < IGNORE ** 2 or rec[0][2] < IGNORE ** 2:
          #print("ignoring '%(source)s' -> '%(target)s' %(rec)s" % locals())
          ignoring.append( (source, target) )
      for pair in ignoring:
        del records[pair]
      # 周辺化したレコードの配列を親プロセスに返す
      if records:
        #debug.print("finished pivoting, source phrase: '%(source)s'" % locals())
        #debug.print(source, len(rows), len(records))
        pivot_queue.put(records)


def flush_pivot_records(db_save, pivot_name, count, pivot_queue):
  #print("flushing pivot records: %d" % pivot_queue.qsize())
  pivot_records = pivot_queue.get()
  for pair in pivot_records.keys():
    last = pair[0]
    break
  insert_records(db_save, pivot_name, pivot_records)
  count.add_pivot_count( len(pivot_records) )
  count.print(last)

def pivot(src_dbfile, table1, table2, save_dbfile, pivot_name, cores=1):
  if not os.path.isfile(src_dbfile):
    print("sqlite3 db file %s not exists", file=sys.stderr)
    sys.exit(2)
  db_src = sqlite3.connect(src_dbfile)
  if os.path.isfile(save_dbfile):
    os.remove(save_dbfile)
  db_save = sqlite3.connect(save_dbfile)
  create_table(db_save, pivot_name)
  create_indices(db_save, pivot_name)

  record_queues = [multiprocessing.Queue() for i in range(0, cores)]
  pivot_queue = multiprocessing.Queue()
  #debug.print(record_queues)
  procs = [multiprocessing.Process(target=proc, args=(record_queues[i], pivot_queue)) for i in range(0, cores)]
  #debug.print(procs)
  for p in procs:
    p.start()

  #debug.print(size)
  cur = select_pivot(db_src, table1, table2)
  # 周辺化を行う対象フレーズ
  # curr_phrase -> pivot_phrase -> target の形の訳出を探す
  curr_phrase = ''
  count = Counter()
  pivot_count = 0
  rows = []
  for row in cur:
    #print(row)
    source = row[0]
    if curr_phrase != source:
      # 新しい原言語フレーズが出てきたので、ここまでのデータを開いてるプロセスに処理してもらう
      while True:
        q = get_empty_queue(procs, record_queues)
        if q:
          #debug.print(q)
          break
        if not pivot_queue.empty():
          flush_pivot_records(db_save, pivot_name, count, pivot_queue)
      q.put(rows)
      rows = []
      curr_phrase = source
    count.add_row_count()
    rows.append(row)
    if not pivot_queue.empty():
      flush_pivot_records(db_save, pivot_name, count, pivot_queue)
  else:
    # 最後のデータ処理
    while True:
      q = get_empty_queue(procs, record_queues)
      if q:
        break
    q.put(rows)

  # すべてのワーカープロセスの終了（全てのキューが空になる）まで待つ
  while not empty_all(record_queues):
    pass
  # ワーカープロセスを停止させる
  for p in procs:
    p.terminate()
  # ピボットキューの残りを全て書き出す
  while not pivot_queue.empty():
    flush_pivot_records(db_save, pivot_name, count, pivot_queue)
  count.print()
  db_save.commit()
  db_save.close()
  db_src.close()

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description = 'load 2 phrase tables from sqlite3 and pivot into sqlite3 table')
  parser.add_argument('src_dbfile', help = 'sqlite3 dbfile including following source tables')
  parser.add_argument('table1', help = 'table name for task 1 of moses phrase-table')
  parser.add_argument('table2', help = 'table name for task 2 of moses phrase-table')
  parser.add_argument('save_dbfile', help = 'sqlite3 dbfile to result storing (can be the same with src_dbfile)')
  parser.add_argument('pivot_name', help = 'table name for pivoted phrase-table')
  parser.add_argument('--cores', help = 'number of processes parallel computing', type=int, default=1)
  parser.add_argument('--ignore', help = 'threshold for ignoring the phrase translation probability (real number)', type=float, default=IGNORE)
  args = vars(parser.parse_args())
  #debug.print(args)

  IGNORE = args['ignore']
  del args['ignore']
  pivot(**args)

