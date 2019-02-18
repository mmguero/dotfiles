#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

import argparse
import datetime
import os
import platform
import pprint
import re
import sys

from subprocess import (PIPE, Popen)
from collections import defaultdict, namedtuple

###################################################################################################
debug = False
PY3 = (sys.version_info.major >= 3)
scriptName = os.path.basename(__file__)
scriptPath = os.path.dirname(os.path.realpath(__file__))
origPath = os.getcwd()

###################################################################################################
if not PY3:
  if hasattr(__builtins__, 'raw_input'): input = raw_input

try:
  FileNotFoundError
except NameError:
  FileNotFoundError = IOError

###################################################################################################
# print to stderr
def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

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
# get interactive user response to Y/N question
def YesOrNo(question):
  while True:
    reply = str(input(question+' (y/n): ')).lower().strip()
    if len(reply) > 0: break
  if reply[0] == 'y':
    return True
  elif reply[0] == 'n':
    return False
  else:
    return YesOrNo(question)

###################################################################################################
# get interactive user response
def AskForString(question):
  return str(input(question+': ')).strip()

###################################################################################################
# run command with arguments and return its exit code, stdout, and stderr
def check_output_input(*popenargs, **kwargs):

  if 'stdout' in kwargs:
    raise ValueError('stdout argument not allowed, it will be overridden')

  if 'stderr' in kwargs:
    raise ValueError('stderr argument not allowed, it will be overridden')

  if 'input' in kwargs and kwargs['input']:
    if 'stdin' in kwargs:
      raise ValueError('stdin and input arguments may not both be used')
    inputdata = kwargs['input']
    kwargs['stdin'] = PIPE
  else:
    inputdata = None
  kwargs.pop('input', None)

  process = Popen(*popenargs, stdout=PIPE, stderr=PIPE, **kwargs)
  try:
    output, errput = process.communicate(inputdata)
  except:
    process.kill()
    process.wait()
    raise

  retcode = process.poll()

  return retcode, output, errput

###################################################################################################
# run command with arguments and return its exit code and output
def run_process(command, stdout=True, stderr=True, stdin=None):
  global debug

  retcode = -1
  output = []

  try:
    # run the command
    retcode, cmdout, cmderr = check_output_input(command, input=stdin.encode() if (PY3 and stdin) else stdin)

    # split the output on newlines to return a list
    if PY3:
      if stderr and (len(cmderr) > 0): output.extend(cmderr.decode(sys.getdefaultencoding()).split('\n'))
      if stdout and (len(cmdout) > 0): output.extend(cmdout.decode(sys.getdefaultencoding()).split('\n'))
    else:
      if stderr and (len(cmderr) > 0): output.extend(cmderr.split('\n'))
      if stdout and (len(cmdout) > 0): output.extend(cmdout.split('\n'))

  except (FileNotFoundError, OSError, IOError) as e:
    if stderr:
      output.append("Command {} not found or unable to execute".format(command))

  if debug:
    eprint("{}{} returned {}: {}".format(command, "({})".format(stdin[:80] + bool(stdin[80:]) * '...' if stdin else ""), retcode, output))

  return retcode, output

###################################################################################################
# main
def main():
  global debug

  parser = argparse.ArgumentParser(description=scriptName, add_help=False, usage='{} <arguments>'.format(scriptName))
  parser.add_argument('-v', '--verbose', dest='debug', type=str2bool, nargs='?', const=True, default=False, help="Verbose output")
  parser.add_argument('--input', metavar='<STR>', type=str, nargs='*', default='', help='Input file(s)')
  try:
    parser.error = parser.exit
    args = parser.parse_args()
  except SystemExit:
    parser.print_help()
    exit(2)

  debug = args.debug
  if debug:
    eprint(os.path.join(scriptPath, scriptName))
    eprint("Arguments: {}".format(sys.argv[1:]))
    eprint("Arguments: {}".format(args))
  else:
    sys.tracebacklimit = 0

if __name__ == '__main__':
  main()
