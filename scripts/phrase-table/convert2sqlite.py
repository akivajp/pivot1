#!/usr/bin/env python3
# encoding: utf-8

import gzip
import re
import sqlite3
import sys

# local libraries
import debug
import progress

def usage():
  print("usage: %s path1/to/phrase-table.gz dbfile table_name" % sys.argv[0])
  sys.exit(1)

def get_content_size(path):
  try:
    f_in = open(path, 'rb')
    f_in.seek(-8, 2)
    crc32 = gzip.read32(f_in)
    isize = gzip.read32(f_in)
    f_in.close()
    return isize
  except:
    return -1

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
  #source = re.escape(source)
  #target = re.escape(target)
  sql = '''
    INSERT INTO %(table_name)s VALUES (
      null,
      ?,
      ?,
      "%(scores)s",
      "%(align)s",
      "%(counts)s"
    );
  ''' % locals()
  db.execute(sql, (source, target) )

def convert(table_path, dbfile, table_name):
  f_in = gzip.open(table_path, 'r')
  print("loading phrase table file: %s" % table_path)
  size = get_content_size(table_path)
  sys.stdout.write("loading (0%): 0 records")
  db = sqlite3.connect(dbfile)
  drop_table(db, table_name)
  create_table(db, table_name)
  make_indices(db, table_name)
  n = 0
  scale = 10
  for line in f_in:
    n += 1
    line = line.decode('utf-8')
    fields = line.strip().split('|||')
    source = fields[0].strip()
    target = fields[1].strip()
    scores = fields[2].strip()
    align  = fields[3].strip()
    counts = fields[4].strip()
    insert_record(db, table_name, source, target, scores, align, counts)
    if n % scale == 0:
      ratio = f_in.tell() * 100.0 / size
      progress.print("loaded (%(ratio)3.2f%%): %(n)d records, last phrase: '%(source)s'" % locals())
    if n > scale * 100:
      scale *= 10
  progress.print("loaded (100%%): %(n)d records" % locals() )
  print()
  db.commit()
  db.close()


if __name__ == '__main__':
  if len(sys.argv) < 4:
    usage()
  table_path = sys.argv[1]
  db_path = sys.argv[2]
  table_name = sys.argv[3]
  convert(table_path, db_path, table_name)

