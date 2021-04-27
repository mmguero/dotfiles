#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import datetime
import fileinput
import getpass
import glob
import json
import os
import platform
import pprint
import math
import re
import shutil
import sys
import tarfile
import tempfile
import time
from pathlib import Path
from collections import defaultdict, namedtuple

try:
  from pwd import getpwuid
except ImportError:
  getpwuid = None

from mmguero import eprint, str2bool
import mmguero

###################################################################################################
ScriptPath = os.path.dirname(os.path.realpath(__file__))
ScriptName = os.path.basename(__file__)
origPath = os.getcwd()

###################################################################################################
args = None

###################################################################################################
# get interactive user response to Y/N question
def InstallerYesOrNo(question, default=None, forceInteraction=False):
  global args
  return mmguero.YesOrNo(question, default=default, forceInteraction=forceInteraction, acceptDefault=args.acceptDefaults)

###################################################################################################
# get interactive user response
def InstallerAskForString(question, default=None, forceInteraction=False):
  global args
  return mmguero.AskForString(question, default=default, forceInteraction=forceInteraction, acceptDefault=args.acceptDefaults)

def TrueOrFalseQuote(expression):
  return "'{}'".format('true' if expression else 'false')

###################################################################################################
class Installer(object):

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def __init__(self, debug=False, configOnly=False):
    self.debug = debug
    self.configOnly = configOnly

    self.platform = platform.system()
    self.scriptUser = getpass.getuser()
    self.arch = platform.machine()
    self.archPkg = self.arch

    self.homePath = str(Path.home())
    self.configPath = None
    self.tempDirName = tempfile.mkdtemp()

    self.checkPackageCmds = []
    self.installPackageCmds = []
    self.requiredPackages = []

    self.pyExec = sys.executable
    self.pyExecUserOwned = (getpass.getuser() == getpwuid(os.stat(self.pyExec).st_uid).pw_name)
    self.pipCmd = [self.pyExec, '-m', 'pip']
    self.installPipPackageCmds = []

    # default pip packages
    self.pipPackages = []

    self.totalMemoryGigs = 0.0
    self.totalCores = 0

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def __del__(self):
    shutil.rmtree(self.tempDirName, ignore_errors=True)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def run_process(self, command, stdout=True, stderr=True, stdin=None, privileged=False, retry=0, retrySleepSec=5):

    # if privileged, put the sudo command at the beginning of the command
    if privileged and (len(self.sudoCmd) > 0):
      command = self.sudoCmd + command

    return mmguero.RunProcess(command, stdout=stdout, stderr=stderr, stdin=stdin, retry=retry, retrySleepSec=retrySleepSec, debug=self.debug)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def package_is_installed(self, package):
    result = False
    for cmd in self.checkPackageCmds:
      ecode, out = self.run_process(cmd + [package])
      if (ecode == 0):
        result = True
        break
    return result

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def install_package(self, packages):
    result = False
    pkgs = []

    for package in packages:
      if not self.package_is_installed(package):
        pkgs.append(package)

    if (len(pkgs) > 0):
      for cmd in self.installPackageCmds:
        ecode, out = self.run_process(cmd + pkgs, privileged=True)
        if (ecode == 0):
          result = True
          break
    else:
      result = True

    return result

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def install_required_packages(self):
    if (len(self.requiredPackages) > 0): eprint(f"Installing required packages: {self.requiredPackages}")
    return self.install_package(self.requiredPackages)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def install_pip_packages(self):

    # pip
    if (len(self.pipPackages) > 0):
      eprint(f"Installing pip packages: {self.pipPackages}")
      for pipPkg in self.pipPackages:
        err, out = self.run_process(self.installPipPackageCmds + [pipPkg])
        if (err == 0):
          eprint(f"Installation of {pipPkg} apparently succeeded")
        else:
          eprint(f"Install {pipPkg} via pip failed with {err}, {out}")

      err, out = self.run_process(self.pipCmd + ['show', 'chepy'])
      if (err == 0) and (len(out) > 0) and not os.path.isdir(os.path.join(self.configPath, 'chepy_plugins')):
        GitClone('https://github.com/securisec/chepy_plugins',
                 os.path.join(self.configPath, 'chepy_plugins'))

###################################################################################################
class LinuxInstaller(Installer):

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def __init__(self, debug=False, configOnly=False):
    super().__init__(debug, configOnly)

    self.configPath = os.getenv('XDG_CONFIG_HOME')
    if not self.configPath:
      self.configPath = os.path.join(self.homePath, '.config')

    self.distro = None
    self.codename = None
    self.release = None

    # determine the distro (e.g., ubuntu) and code name (e.g., bionic) if applicable

    # check /etc/os-release values first
    if os.path.isfile('/etc/os-release'):
      osInfo = dict()

      with open("/etc/os-release", 'r') as f:
        for line in f:
          try:
            k, v = line.rstrip().split("=")
            osInfo[k] = v.strip('"')
          except:
            pass

      if ('NAME' in osInfo) and (len(osInfo['NAME']) > 0):
        distro = osInfo['NAME'].lower().split()[0]

      if ('VERSION_CODENAME' in osInfo) and (len(osInfo['VERSION_CODENAME']) > 0):
        codename = osInfo['VERSION_CODENAME'].lower().split()[0]

      if ('VERSION_ID' in osInfo) and (len(osInfo['VERSION_ID']) > 0):
        release = osInfo['VERSION_ID'].lower().split()[0]

    # try lsb_release next
    if (self.distro is None):
      err, out = self.run_process(['lsb_release', '-is'], stderr=False)
      if (err == 0) and (len(out) > 0):
        self.distro = out[0].lower()

    if (self.codename is None):
      err, out = self.run_process(['lsb_release', '-cs'], stderr=False)
      if (err == 0) and (len(out) > 0):
        self.codename = out[0].lower()

    if (self.release is None):
      err, out = self.run_process(['lsb_release', '-rs'], stderr=False)
      if (err == 0) and (len(out) > 0):
        self.release = out[0].lower()

    # try release-specific files
    if (self.distro is None):
      if os.path.isfile('/etc/centos-release'):
        distroFile = '/etc/centos-release'
      if os.path.isfile('/etc/redhat-release'):
        distroFile = '/etc/redhat-release'
      elif os.path.isfile('/etc/issue'):
        distroFile = '/etc/issue'
      else:
        distroFile = None
      if (distroFile is not None):
        with open(distroFile, 'r') as f:
          distroVals = f.read().lower().split()
          distroNums = [x for x in distroVals if x[0].isdigit()]
          self.distro = distroVals[0]
          if (self.release is None) and (len(distroNums) > 0):
            self.release = distroNums[0]

    if (self.distro is None):
      self.distro = "linux"

    if self.debug:
      eprint(f"distro: {self.distro}{f' {self.codename}' if self.codename else ''}{f' {self.release}' if self.release else ''}")

    if not self.codename: self.codename = self.distro

    if self.distro in (mmguero.PLATFORM_LINUX_UBUNTU, mmguero.PLATFORM_LINUX_DEBIAN, mmguero.PLATFORM_LINUX_RASPBIAN):
      self.requiredPackages.extend(['curl', 'git', 'moreutils', 'jq'])
    elif self.distro in (mmguero.PLATFORM_LINUX_FEDORA, mmguero.PLATFORM_LINUX_CENTOS):
      # todo: check this
      self.requiredPackages.extend(['curl', 'git', 'moreutils', 'jq'])

    # on Linux this script requires root, or sudo, unless we're in local configuration-only mode
    if os.getuid() == 0:
      self.scriptUser = "root"
      self.sudoCmd = []
    else:
      self.sudoCmd = ["sudo", "-n"]
      err, out = self.run_process(['whoami'], privileged=True)
      if ((err != 0) or (len(out) == 0) or (out[0] != 'root')) and (not self.configOnly):
        raise Exception(f'{ScriptName} must be run as root, or {self.sudoCmd} must be available')

    # determine command to use to query if a package is installed
    if mmguero.Which('dpkg', debug=self.debug):
      os.environ["DEBIAN_FRONTEND"] = "noninteractive"
      self.checkPackageCmds.append(['dpkg', '-s'])
      err, out = self.run_process(['dpkg', '--print-architecture'])
      if (err == 0) and (len(out) == 1):
        self.archPkg = out[0]
    elif mmguero.Which('rpm', debug=self.debug):
      self.checkPackageCmds.append(['rpm', '-q'])
    elif mmguero.Which('dnf', debug=self.debug):
      self.checkPackageCmds.append(['dnf', 'list', 'installed'])
    elif mmguero.Which('yum', debug=self.debug):
      self.checkPackageCmds.append(['yum', 'list', 'installed'])

    # determine command to install a package from the distro's repos
    if mmguero.Which('apt-get', debug=self.debug):
      self.installPackageCmds.append(['apt-get', 'install', '-y', '-qq'])
    elif mmguero.Which('apt', debug=self.debug):
      self.installPackageCmds.append(['apt', 'install', '-y', '-qq'])
    elif mmguero.Which('dnf', debug=self.debug):
      self.installPackageCmds.append(['dnf', '-y', 'install', '--nobest'])
    elif mmguero.Which('yum', debug=self.debug):
      self.installPackageCmds.append(['yum', '-y', 'install'])

    # determine total system memory
    try:
      totalMemBytes = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES')
      self.totalMemoryGigs = math.ceil(totalMemBytes/(1024.**3))
    except:
      self.totalMemoryGigs = 0.0

    # determine total system memory a different way if the first way didn't work
    if (self.totalMemoryGigs <= 0.0):
      err, out = self.run_process(['awk', '/MemTotal/ { printf "%.0f \\n", $2 }', '/proc/meminfo'])
      if (err == 0) and (len(out) > 0):
        totalMemKiloBytes = int(out[0])
        self.totalMemoryGigs = math.ceil(totalMemKiloBytes/(1024.**2))

    # determine total system CPU cores
    try:
      self.totalCores = os.sysconf('SC_NPROCESSORS_ONLN')
    except:
      self.totalCores = 0

    # determine total system CPU cores a different way if the first way didn't work
    if (self.totalCores <= 0):
      err, out = self.run_process(['grep', '-c', '^processor', '/proc/cpuinfo'])
      if (err == 0) and (len(out) > 0):
        self.totalCores = int(out[0])

    if self.pyExecUserOwned:
      # we're running a user-owned python, regular pip should work
      self.installPipPackageCmds = self.pipCmd + ['install']
    else:
      # python is owned by system, so make sure to pass the --user flag
      self.installPipPackageCmds = self.pipCmd + ['install', '--user']


###################################################################################################
class MacInstaller(Installer):

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def __init__(self, debug=False, configOnly=False):
    super().__init__(debug, configOnly)

    self.sudoCmd = []

    self.configPath = os.getenv('XDG_CONFIG_HOME')
    if not self.configPath:
      self.configPath = os.path.join(self.homePath, '.config')

    # first see if brew is already installed and runnable
    err, out = self.run_process(['brew', 'info'])
    brewInstalled = (err == 0)

    if brewInstalled and InstallerYesOrNo('Homebrew is installed: continue with Homebrew?', default=True):
      self.useBrew = True

    else:
      self.useBrew = False
      if (not brewInstalled) and (not InstallerYesOrNo('Homebrew is not installed: continue with manual installation?', default=False)):
        raise Exception(f'Follow the steps at {HOMEBREW_INSTALL_URLS[self.platform]} to install Homebrew, then re-run {ScriptName}')

    if self.useBrew:
      # make sure we have brew cask
      err, out = self.run_process(['brew', 'info', 'cask'])
      if (err != 0):
        self.install_package(['cask'])
        if (err == 0):
          if self.debug: eprint('"brew install cask" succeeded')
        else:
          eprint(f'"brew install cask" failed with {err}, {out}')

      err, out = self.run_process(['brew', 'tap', 'homebrew/cask-versions'])
      if (err == 0):
        if self.debug: eprint('"brew tap homebrew/cask-versions" succeeded')
      else:
        eprint(f'"brew tap homebrew/cask-versions" failed with {err}, {out}')

      err, out = self.run_process(['brew', 'tap', 'homebrew/cask-fonts'])
      if (err == 0):
        if self.debug: eprint('"brew tap homebrew/cask-fonts" succeeded')
      else:
        eprint(f'"brew tap homebrew/cask-fonts" failed with {err}, {out}')

      self.checkPackageCmds.append(['brew', 'cask', 'ls', '--versions'])
      self.installPackageCmds.append(['brew', 'cask', 'install'])

      self.requiredPackages.extend(['git', 'moreutils', 'jq'])

    # determine total system memory
    try:
      totalMemBytes = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES')
      self.totalMemoryGigs = math.ceil(totalMemBytes/(1024.**3))
    except:
      self.totalMemoryGigs = 0.0

    # determine total system memory a different way if the first way didn't work
    if (self.totalMemoryGigs <= 0.0):
      err, out = self.run_process(['sysctl', '-n', 'hw.memsize'])
      if (err == 0) and (len(out) > 0):
        totalMemBytes = int(out[0])
        self.totalMemoryGigs = math.ceil(totalMemBytes/(1024.**3))

    # determine total system CPU cores
    try:
      self.totalCores = os.sysconf('SC_NPROCESSORS_ONLN')
    except:
      self.totalCores = 0

    # determine total system CPU cores a different way if the first way didn't work
    if (self.totalCores <= 0):
      err, out = self.run_process(['sysctl', '-n', 'hw.ncpu'])
      if (err == 0) and (len(out) > 0):
        self.totalCores = int(out[0])

    if self.pyExecUserOwned:
      # we're running a user-owned python, regular pip should work
      self.installPipPackageCmds = self.pipCmd + ['install']
    else:
      # python is owned by system, so make sure to pass the --user flag
      self.installPipPackageCmds = self.pipCmd + ['install', '--user']

    self.pipPackages.extend(['Cython', 'psutil'])

###################################################################################################
# main
def main():
  global args

  # extract arguments from the command line
  # print (sys.argv[1:]);
  parser = argparse.ArgumentParser(description='Malcolm install script', add_help=False, usage=f'{ScriptName} <arguments>')
  parser.add_argument('-v', '--verbose', dest='debug', type=str2bool, nargs='?', const=True, default=False, help="Verbose output")
  parser.add_argument('-c', '--configure', dest='configOnly', type=str2bool, nargs='?', const=True, default=False, help="Only do configuration (not installation)")
  parser.add_argument('-d', '--defaults', dest='acceptDefaults', type=str2bool, nargs='?', const=True, default=False, help="Accept defaults to prompts without user interaction")

  try:
    parser.error = parser.exit
    args = parser.parse_args()
  except SystemExit:
    parser.print_help()
    exit(2)

  if args.debug:
    eprint(os.path.join(ScriptPath, ScriptName))
    eprint(f"Arguments: {sys.argv[1:]}")
    eprint(f"Arguments: {args}")
    os.environ["GIT_PYTHON_TRACE"] = "full"
    import logging
    logging.basicConfig(level=logging.INFO)
  else:
    sys.tracebacklimit = 0

  if not mmguero.DoDynamicImport('requests', 'requests', debug=args.debug):
    exit(2)
  if not mmguero.DoDynamicImport('git', 'GitPython', debug=args.debug):
    exit(2)

  if args.debug:
    if args.configOnly:
      eprint("Only doing configuration, not installation")

  installerPlatform = platform.system()
  if installerPlatform == mmguero.PLATFORM_LINUX:
    installer = LinuxInstaller(debug=args.debug, configOnly=args.configOnly)
  elif installerPlatform == mmguero.PLATFORM_MAC:
    installer = MacInstaller(debug=args.debug, configOnly=args.configOnly)
  elif installerPlatform == mmguero.PLATFORM_WINDOWS:
    raise Exception(f'{ScriptName} is not yet supported on {installerPlatform}')
    installer = WindowsInstaller(debug=args.debug, configOnly=args.configOnly)

  success = False
  installPath = None

  if (not args.configOnly):
    if hasattr(installer, 'install_required_packages'): success = installer.install_required_packages()

  if (hasattr(installer, 'install_pip_packages') and InstallerYesOrNo('Install pip packages?', default=False)):
    success = installer.install_pip_packages()

if __name__ == '__main__':
  main()
