#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import sys

from subprocess import (PIPE, Popen)

###################################################################################################
args = None
debug = False
script_name = os.path.basename(__file__)
script_path = os.path.dirname(os.path.realpath(__file__))
orig_path = os.getcwd()

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
# get interactive user response to Y/N question
def yes_or_no(question, default=None, force_interaction=False):
  global args

  if default == True:
    question_str = "\n{} (Y/n): ".format(question)
  elif default == False:
    question_str = "\n{} (y/N): ".format(question)
  else:
    question_str = "\n{} (y/n): ".format(question)

  if args.accept_defaults and (default is not None) and (not force_interaction):
    reply = ''
  else:
    while True:
      reply = str(input(question_str)).lower().strip()
      if (len(reply) > 0) or (default is not None):
        break

  if (len(reply) == 0):
    reply = 'y' if default else 'n'

  if reply[0] == 'y':
    return True
  elif reply[0] == 'n':
    return False
  else:
    return yes_or_no(question, default=default)

###################################################################################################
# get interactive user response
def ask_for_string(question, default=None, force_interaction=False):
  global args

  if args.accept_defaults and (default is not None) and (not force_interaction):
    reply = default
  else:
    reply = str(input('\n{}: '.format(question))).strip()

  return reply

###################################################################################################
# nice human-readable file sizes
def sizeof_fmt(num, suffix='B'):
  for unit in ['','Ki','Mi','Gi','Ti','Pi','Ei','Zi']:
    if abs(num) < 1024.0:
      return "%3.1f%s%s" % (num, unit, suffix)
    num /= 1024.0
  return "%.1f%s%s" % (num, 'Yi', suffix)

###################################################################################################
# test if a remote port is open
def test_socket(host, port):
  with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
    sock.settimeout(10)
    if sock.connect_ex((host, port)) == 0:
      return True
    else:
      return False

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
    input_data = kwargs['input']
    kwargs['stdin'] = PIPE
  else:
    input_data = None
  kwargs.pop('input', None)

  process = Popen(*popenargs, stdout=PIPE, stderr=PIPE, **kwargs)
  try:
    output, errput = process.communicate(input_data)
  except:
    process.kill()
    process.wait()
    raise

  retcode = process.poll()

  return retcode, output, errput

###################################################################################################
# run command with arguments and return its exit code and output
def run_process(command, stdout=True, stderr=True, stdin=None, cwd=None, env=None, debug=False):

  retcode = -1
  output = []

  try:
    # run the command
    retcode, cmdout, cmderr = check_output_input(command, input=stdin.encode() if stdin else None, cwd=cwd, env=env)

    # split the output on newlines to return a list
    if stderr and (len(cmderr) > 0): output.extend(cmderr.decode(sys.getdefaultencoding()).split('\n'))
    if stdout and (len(cmdout) > 0): output.extend(cmdout.decode(sys.getdefaultencoding()).split('\n'))

  except (FileNotFoundError, OSError, IOError) as e:
    if stderr:
      output.append("Command {} not found or unable to execute".format(command))

  if debug:
    eprint("{}{} returned {}: {}".format(command, "({})".format(stdin[:80] + bool(stdin[80:]) * '...' if stdin else ""), retcode, output))

  return retcode, output

###################################################################################################
# main
def main():
  global args
  global debug

  parser = argparse.ArgumentParser(description=script_name, add_help=False, usage='{} <arguments>'.format(script_name))
  parser.add_argument('-d', '--defaults', dest='accept_defaults', type=str2bool, nargs='?', const=True, default=False, metavar='true|false', help="Accept defaults to prompts without user interaction")
  parser.add_argument('-v', '--verbose', dest='debug', type=str2bool, nargs='?', const=True, default=False, metavar='true|false', help="Verbose/debug output")
  parser.add_argument('-i', '--input', dest='input', type=str, default=None, required=False, metavar='<string>', help="Input")
  try:
    parser.error = parser.exit
    args = parser.parse_args()
  except SystemExit:
    parser.print_help()
    exit(2)

  debug = args.debug
  if debug:
    eprint(os.path.join(script_path, script_name))
    eprint("Arguments: {}".format(sys.argv[1:]))
    eprint("Arguments: {}".format(args))
  else:
    sys.tracebacklimit = 0

  if args.input is not None:
    cmd_code, cmd_output = run_process(args.input)
    print(f"{cmd_code}: {cmd_output}")

###################################################################################################
if __name__ == '__main__':
  main()
