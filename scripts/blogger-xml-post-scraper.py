#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import base64
import feedparser
import fileinput
import os
import pprint
import re
import sys
import tempfile
import time
import zipfile

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
# libreoffice is inserting a hard break before each page
# need to:
# 1. open odt file
# 2. in content.xml
#     - style:master-page-name="HTML" -> style:master-page-name=""
#     - <style:paragraph-properties style:page-number="auto"/> -> <style:paragraph-properties style:page-number="auto" fo:break-before="auto" fo:break-after="auto"/>
# 3. re-save odt file
def tweakODT(odtfile):
  try:
    # create and navigate to a temporary directory
    with tempfile.TemporaryDirectory() as tmpDirName:
      with mmguero.pushd(tmpDirName):
        # open the original ODT (zip file) and extract content.xml which contains the style elements we need to mess with
        with zipfile.ZipFile(odtfile, 'r') as origOdt:
          origOdt.extract('content.xml')
          if os.path.isfile('content.xml'):
            # read content.xml and modify the style elements we need to mess with, in-place
            with fileinput.FileInput('content.xml', inplace=True, backup=None) as content:
                for line in content:
                  line = re.sub(r'(style:master-page-name=)"[^\"]*"', r'\1""', line)
                  line = re.sub(r'(<style:paragraph-properties\b.*?)/>', r'\1 fo:break-before="auto" fo:break-after="auto"/>', line)
                  print(line)
            # create and open the new ODT (zip file)
            tmpfd, tmpname = tempfile.mkstemp(dir=tmpDirName)
            os.close(tmpfd)
            with zipfile.ZipFile(tmpname, 'w') as newOdt:
              # transfer contents of original ODT to new ODT except for content.xml
              newOdt.comment = origOdt.comment
              for item in origOdt.infolist():
                if item.filename != 'content.xml':
                  newOdt.writestr(item, origOdt.read(item.filename))
              # write modified content.xml
              newOdt.write('content.xml', 'content.xml')
        # replace the original ODT with the new ODT
        if os.path.isfile(tmpname):
          os.remove(odtfile)
          os.rename(tmpname, odtfile)

  except Exception as e:
    eprint(f"exception: {e}")

###################################################################################################
def guessType(filepath):
  try:
    import magic  # python-magic
    return magic.from_file(filepath, mime=True)
  except ImportError:
    import mimetypes
    return mimetypes.guess_type(filepath)[0]

###################################################################################################
def fileToBase64(filepath):
    with open(filepath, 'rb') as f:
      encoded_str = base64.b64encode(f.read())
    return encoded_str.decode('utf-8')

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
      fileParts = os.path.splitext(path)
      outFileSpec = fileParts[0] + "_scrubbed" + fileParts[1]
      outPath = os.path.dirname(outFileSpec)
      soup = BeautifulSoup(open(path), 'html.parser')

      # for blogger "simple theme", we're going to prune and clean out all kinds of tags we don't need

      # move lowest level containing actual blog post up to the top of body
      if body := soup.find('body'):
        movedMain = False
        for div in soup.find_all("div", { 'class' : 'date-outer' }):
          body.insert(0, div)
          movedMain = True
        if movedMain:
          for div in soup.find_all("div", { 'class' : 'content' }):
            div.decompose()

      # remove divs we don't care about baed on class, id, and style
      for divClass in [ 'clear', 'tabs-outer', 'column-right-outer', 'header-outer', 'post-header', 'post-footer', 'comments', 'content-cap-top', 'cap-top', 'cap-bottom', 'footer-outer', 'post-feeds', 'fauxcolumn-outer', 'fauxborder-right', 'content-fauxcolumns', 'body-fauxcolumns', 'column-left-inner', 'column-left-outer']:
        for div in soup.find_all("div", { 'class' : divClass }):
          div.decompose()
      for divId in ['b-navbar-fg', 'b-navbar-bg', 'b-navbar', 'Navbar1', 'navbar', 'blog-pager']:
        for div in soup.find_all("div", { 'id' : divId }):
          div.decompose()
      for divStyle in ['clear: both;']:
        for div in soup.find_all("div", { 'style' : divStyle }):
          div.decompose()

      # remove other tag types we don't care about
      for tagType in ['head', 'footer', 'iframe', 'meta', 'header', 'noscript', 'aside']:
        for tag in soup.find_all(tagType):
          tag.decompose()

      # remove html comments
      [comment.extract() for comment in soup.findAll(text=lambda text: isinstance(text, Comment))]

      # remove javascript
      [tag.extract() for tag in soup.findAll("script")]

      # embed images using base64 rather than linking to files
      for img in soup.find_all('img'):
        imgPath = os.path.join(outPath, img.attrs['src']) if ('src' in img.attrs) else ''
        if os.path.isfile(imgPath):
          mimetype = guessType(imgPath)
          img.attrs['src'] = f"data:{mimetype};base64,{fileToBase64(imgPath)}"
        # insert a hard break before each image
        img.insert_after(soup.new_tag('br',attrs={"clear": "all"}))

      # write massaged HTML file
      with open(outFileSpec, 'wb') as f:
        f.write(soup.prettify('utf-8'))

      # convert to libreoffice odt
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
        newOdtFileName = os.path.join(args.output, f"{dateparse(post['published']).strftime('%Y-%m-%d_%H-%M')}_{os.path.basename(odtFileName).replace('_scrubbed', '')}")
        os.rename(odtFileName, newOdtFileName)
        tweakODT(newOdtFileName)

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
