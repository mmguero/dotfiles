#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import sys

import mmguero

###################################################################################################
args = None
debug = False
script_name = os.path.basename(__file__)
script_path = os.path.dirname(os.path.realpath(__file__))
orig_path = os.getcwd()

###################################################################################################
# main
def main():
  global args
  global debug

  parser = argparse.ArgumentParser(description=script_name, add_help=False, usage='{} <arguments>'.format(script_name))
  parser.add_argument('-d', '--defaults', dest='accept_defaults', type=mmguero.str2bool, nargs='?', const=True, default=False, metavar='true|false', help="Accept defaults to prompts without user interaction")
  parser.add_argument('-v', '--verbose', dest='debug', type=mmguero.str2bool, nargs='?', const=True, default=False, metavar='true|false', help="Verbose/debug output")
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
    cmd_code, cmd_output = mmguero.RunProcess(args.input)
    print(f"{cmd_code}: {cmd_output}")

###################################################################################################
if __name__ == '__main__':
  main()
