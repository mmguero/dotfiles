#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import sys
import datetime
import requests
import json
from bs4 import BeautifulSoup as bs
import sqlite3
import re
from sqlite3 import Error as SQLError

from subprocess import (PIPE, Popen)

###################################################################################################
args = None
debug = False
script_name = os.path.basename(__file__)
script_path = os.path.dirname(os.path.realpath(__file__))
orig_path = os.getcwd()

TABLE_NAME="projects"
PROJECT_FIELD="project"
TAGS_FIELD="tag"
TIME_FIELD="refreshed"

sql_create_projects_table = f"CREATE TABLE IF NOT EXISTS {TABLE_NAME} ({PROJECT_FIELD} text NOT NULL, {TAGS_FIELD} text, {TIME_FIELD} timestamp, PRIMARY KEY ({TAGS_FIELD}));"

flatten = lambda *n: (e for a in n
    for e in (flatten(*a) if isinstance(a, (tuple, list)) else (a,)))

###################################################################################################
# print to stderr
def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)
  sys.stderr.flush()

###################################################################################################
# convenient boolean argument parsing
def str2bool(v):
  if v.lower() in ('yes', 'true', 't', 'y', '1'):
    return True
  elif v.lower() in ('no', 'false', 'f', 'n', '0'):
    return False
  else:
    raise argparse.ArgumentTypeError('Boolean value expected.')

###################################################################################################
# nice human-readable file sizes
def sizeof_fmt(num, suffix='B'):
  for unit in ['','Ki','Mi','Gi','Ti','Pi','Ei','Zi']:
    if abs(num) < 1024.0:
      return "%3.1f%s%s" % (num, unit, suffix)
    num /= 1024.0
  return "%.1f%s%s" % (num, 'Yi', suffix)

def create_table(conn, create_sql):
  try:
    cursor = conn.cursor()
    cursor.execute(create_sql)
  except Exception as e:
    eprint('"{}" raised for "{}"'.format(str(e), create_sql))

def update_tags(conn, project, tags):
  try:
    cursor = conn.cursor()
    cursor.execute(f"REPLACE INTO {TABLE_NAME}({PROJECT_FIELD}, {TAGS_FIELD}, {TIME_FIELD}) VALUES ('{project}', '{json.dumps(tags) if ((tags is not None) and (len(tags) > 0)) else 'NULL'}', '{datetime.datetime.now()}')")
  except Exception as e:
    eprint('"{}" raised for {}: {}'.format(str(e), project, tags))

def get_tags(conn, project):
  global debug
  try:
    cursor = conn.cursor()
    cursor.execute(f"SELECT {TAGS_FIELD} FROM {TABLE_NAME} WHERE ({PROJECT_FIELD} = '{project}')")
    results = cursor.fetchall()
    tags = None
    if (results is not None) and  (len(results) > 0):
      tags = [x.lower() for x in list(flatten([json.loads(row[0]) if row[0] != 'NULL' else [] for row in results]))]
    else:
      response = requests.get(f'https://pypi.python.org/pypi/{project}/json')
      if response.ok:
        pkgInfo = json.loads(response.text)
        if ('info' in pkgInfo) and ('keywords' in pkgInfo['info']) and (pkgInfo['info']['keywords']):
          # this is a pain, because keywords doesn't seem to be consistent:
          #   https://pypi.org/pypi/colored/json has:  color,colour,paint,ansi,terminal,linux,python
          #   https://pypi.org/pypi/colorama/json has: color colour terminal text ansi windows crossplatform xplatform
          #   https://pypi.org/pypi/aam/json has:      Aam,about me,site,static,static page,static site,generator
          # so I guess split on commas if there are any commas, else split on space
          tags = [x.strip().lower() for x in pkgInfo['info']['keywords'].split(','  if (',' in pkgInfo['info']['keywords']) else ' ')]
          update_tags(conn, project, tags)
        else:
          update_tags(conn, project, [])
      elif response.status_code == 404:
        update_tags(conn, project, [])

    return tags
  except Exception as e:
    eprint('"{}" raised for "{}"'.format(str(e), project))

###################################################################################################
# main
def main():
  global args
  global debug

  parser = argparse.ArgumentParser(description=script_name, add_help=False, usage='{} <arguments>'.format(script_name))
  parser.add_argument('-v', '--verbose', dest='debug', type=str2bool, nargs='?', const=True, default=False, metavar='true|false', help="Verbose/debug output")
  parser.add_argument('-k', '--keywords', dest='tags', action='store', nargs='+', metavar='<keywords>', help="List of keywords to match")
  parser.add_argument('-p', '--projects', dest='projects', action='store', nargs='*', metavar='<projects>', help="List of projects to examine")
  parser.add_argument('-d', '--db', required=False, dest='dbFileSpec', metavar='<STR>', type=str, default=None, help='sqlite3 package tags cache database')
  try:
    parser.error = parser.exit
    args = parser.parse_args()
  except SystemExit as se:
    eprint(se)
    parser.print_help()
    exit(2)

  debug = args.debug
  if debug:
    eprint(os.path.join(script_path, script_name))
    eprint("Arguments: {}".format(sys.argv[1:]))
    eprint("Arguments: {}".format(args))
  else:
    sys.tracebacklimit = 0

  dbPath = args.dbFileSpec if (args.dbFileSpec is not None) else os.path.join(orig_path, 'pypi.db')

  with sqlite3.connect(dbPath) as conn:

    cursor = conn.cursor()
    if debug:
      eprint(f"SQLite version: {cursor.execute('SELECT SQLITE_VERSION()').fetchone()}")
    create_table(conn, sql_create_projects_table)
    if debug:
      eprint(f"{TABLE_NAME} row count: {cursor.execute(f'SELECT COUNT(*) FROM {TABLE_NAME}').fetchone()}")

    if (args.projects is not None):
      projects = args.projects
    else:
      response = requests.get("https://pypi.org/simple")
      soup = bs(response.text, "lxml")
      projects = [x for x in soup.text.split() if x]

    if debug:
      eprint(f"{TABLE_NAME} ({len(projects)}): {projects}")

    filteredProjects = list()
    for project in projects:
      tags = get_tags(conn, project)
      if debug:
        eprint(f"{project} {TAGS_FIELD}s ({len(tags) if (tags is not None) else 0}): {tags}")
      if (tags is not None) and any(item in tags for item in args.tags):
        filteredProjects.append(project)

    print(*filteredProjects, sep = '\n')


###################################################################################################
if __name__ == '__main__':
  main()
