#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import pprint
import sys
import time
import feedparser

from bs4 import BeautifulSoup, Comment
from dateutil.parser import parse as dateparse
from pathlib import Path
from mmguero import eprint
import mmguero

###################################################################################################
args = None
debug = False
script_name = os.path.basename(__file__)
script_path = os.path.dirname(os.path.realpath(__file__))
orig_path = os.getcwd()

###################################################################################################
def parseXML(xmlfile):

    d = feedparser.parse(xmlfile)
    postCount = 0

    posts = []

    for entry in d.entries:
      isPost = False
      if ('tags' in entry) and ('title' in entry) and ('published' in entry) and ('link' in entry):
        for tag in entry['tags']:
          if ('term' in tag) and tag['term'].endswith('kind#post'):
            isPost = True
            break
      if isPost:
        posts.append(entry)

    return sorted(posts, key = lambda e : dateparse(e['published']))

###################################################################################################
def wgetPosts(posts):
  global args
  global debug

  for post in posts:
    eprint(f"{post['link']}...")
    newdir = os.path.join(args.output, f'{dateparse(post["published"]).strftime("%Y-%m-%d_%H:%M:%S")} {"".join([c for c in post["title"] if c.isalpha() or c.isdigit() or c==" "]).rstrip()}')
    try:
      os.mkdir(newdir)
      retCode, output = mmguero.RunProcess(['/usr/bin/wget',
                                            '--convert-links',
                                            '--page-requisites',
                                            '--no-parent',
                                            '--adjust-extension',
                                            '--span-hosts',
                                            '--execute',
                                            'robots=off',
                                            f'--domains={args.blog_address},bp.blogspot.com,blogger.com,googleusercontent.com,ggpht.com,fbcdn.net,akamaihd.net,akamai.net',
                                            '--exclude-domains=www.blogger.com',
                                            post['link']],
                                            cwd=newdir,
                                            debug=debug)
      time.sleep(1)
    except Exception as e:
      eprint(f"exception: {e}")

    for path in Path(os.path.join(newdir, args.blog_address)).rglob('*.html'):
      soup = BeautifulSoup(open(path), 'html.parser')
      # for blogger "simple theme"
      for divClass in [ 'tabs-outer', 'column-right-outer', 'header-outer', 'post-footer', 'comments', 'content-cap-top', 'cap-top', 'cap-bottom', 'footer-outer', 'post-feeds', 'fauxcolumn-outer', 'fauxborder-right', 'content-fauxcolumns', 'body-fauxcolumns']:
        for div in soup.find_all("div", { 'class' : divClass }):
          div.decompose()
      for divId in ['b-navbar-fg', 'b-navbar-bg', 'b-navbar', 'Navbar1', 'navbar', 'blog-pager']:
        for div in soup.find_all("div", { 'id' : divId }):
          div.decompose()
      for tagType in ['head', 'footer', 'iframe', 'meta', 'header', 'noscript']:
        for tag in soup.find_all(tagType):
          tag.decompose()
      [comment.extract() for comment in soup.findAll(text=lambda text: isinstance(text, Comment))]
      [tag.extract() for tag in soup.findAll("script")]
      fileParts = os.path.splitext(path)
      outFileSpec = fileParts[0] + "_scrubbed" + fileParts[1]
      outPath = os.path.dirname(outFileSpec)
      with open(outFileSpec, 'wb') as f:
        f.write(soup.prettify('utf-8'))
      if os.path.isfile(outFileSpec):
        retCode, output = mmguero.RunProcess(['libreoffice',
                                              '--headless',
                                              '--convert-to',
                                              'odt',
                                              '--outdir',
                                              args.output,
                                              outFileSpec],
                                              cwd=args.output,
                                              debug=debug)
        odtFileName = os.path.join(args.output, os.path.basename(os.path.splitext(outFileSpec)[0]+'.odt'))
        newOdtFileName = os.path.join(args.output, f"{dateparse(post['published']).strftime('%Y-%m-%d_%H:%M')}_{os.path.basename(odtFileName).replace('_scrubbed', '')}")
        os.rename(odtFileName, newOdtFileName)

###################################################################################################
# main
def main():
  global args
  global debug

  parser = argparse.ArgumentParser(description=script_name, add_help=False, usage='{} <arguments>'.format(script_name))
  parser.add_argument('-d', '--defaults', dest='accept_defaults', type=mmguero.str2bool, nargs='?', const=True, default=False, metavar='true|false', help="Accept defaults to prompts without user interaction")
  parser.add_argument('-v', '--verbose', dest='debug', type=mmguero.str2bool, nargs='?', const=True, default=False, metavar='true|false', help="Verbose/debug output")
  parser.add_argument('-i', '--input', dest='input', type=str, default=None, required=False, metavar='<string>', help="Input")
  parser.add_argument('-o', '--output', dest='output', type=str, default=None, required=False, metavar='<string>', help="Output directory")
  parser.add_argument('-a', '--address', dest='blog_address', type=str, default=None, required=True, metavar='<string>', help="Blog address (eg., example.blogspot.com")
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
    posts = parseXML(args.input)
    wgetPosts(posts)


###################################################################################################
if __name__ == '__main__':
  main()
