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

from mmguero_common import *

###################################################################################################

DEB_GPG_KEY_FINGERPRINT = '0EBFCD88' # used to verify GPG key for Docker Debian repository


###################################################################################################
ScriptName = os.path.basename(__file__)
origPath = os.getcwd()

###################################################################################################
args = None

###################################################################################################
# get interactive user response to Y/N question
def InstallerYesOrNo(question, default=None, forceInteraction=False):
  global args
  return YesOrNo(question, default=default, forceInteraction=forceInteraction, acceptDefault=args.acceptDefaults)

###################################################################################################
# get interactive user response
def InstallerAskForString(question, default=None, forceInteraction=False):
  global args
  return AskForString(question, default=default, forceInteraction=forceInteraction, acceptDefault=args.acceptDefaults)

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
    self.pipPackages = ['beautifulsoup4',
                        'chepy[extras]',
                        'colorama',
                        'colored',
                        'cryptography',
                        'entrypoint2',
                        'git+git://github.com/badele/gitcheck.git',
                        'git-up',
                        'humanhash3',
                        'magic-wormhole',
                        'patool',
                        'Pillow',
                        'py-cui',
                        'pyinotify',
                        'pythondialog',
                        'python-magic',
                        'pyshark',
                        'pyunpack',
                        'pyyaml',
                        'requests[security]',
                        'scapy',
                        'urllib3',
                        'magic-wormhole']

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

    return run_process(command, stdout=stdout, stderr=stderr, stdin=stdin, retry=retry, retrySleepSec=retrySleepSec, debug=self.debug)

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

    # determine packages required by Malcolm itself (not docker, those will be done later)
    if (self.distro == PLATFORM_LINUX_UBUNTU) or (self.distro == PLATFORM_LINUX_DEBIAN):
      self.requiredPackages.extend(['curl', 'git', 'moreutils', 'jq'])
    elif (self.distro == PLATFORM_LINUX_FEDORA) or (self.distro == PLATFORM_LINUX_CENTOS):
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
    if Which('dpkg', debug=self.debug):
      os.environ["DEBIAN_FRONTEND"] = "noninteractive"
      self.checkPackageCmds.append(['dpkg', '-s'])
    elif Which('rpm', debug=self.debug):
      self.checkPackageCmds.append(['rpm', '-q'])
    elif Which('dnf', debug=self.debug):
      self.checkPackageCmds.append(['dnf', 'list', 'installed'])
    elif Which('yum', debug=self.debug):
      self.checkPackageCmds.append(['yum', 'list', 'installed'])

    # determine command to install a package from the distro's repos
    if Which('apt-get', debug=self.debug):
      self.installPackageCmds.append(['apt-get', 'install', '-y', '-qq'])
    elif Which('apt', debug=self.debug):
      self.installPackageCmds.append(['apt', 'install', '-y', '-qq'])
    elif Which('dnf', debug=self.debug):
      self.installPackageCmds.append(['dnf', '-y', 'install', '--nobest'])
    elif Which('yum', debug=self.debug):
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

    self.pipPackages.extend(['Cython', 'psutil'])

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def setup_sources(self):
    pass

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def install_docker(self):
    result = False

    # first see if docker is already installed and runnable
    err, out = self.run_process(['docker', 'info'], privileged=True)

    if (err == 0):
      result = True

    elif InstallerYesOrNo('"docker info" failed, attempt to install Docker?', default=False):

      if InstallerYesOrNo('Attempt to install Docker using official repositories?', default=True):

        # install required packages for repo-based install
        if self.distro == PLATFORM_LINUX_UBUNTU:
          requiredRepoPackages = ['apt-transport-https', 'ca-certificates', 'curl', 'gnupg-agent', 'software-properties-common']
        elif self.distro == PLATFORM_LINUX_DEBIAN:
          requiredRepoPackages = ['apt-transport-https', 'ca-certificates', 'curl', 'gnupg2', 'software-properties-common']
        elif self.distro == PLATFORM_LINUX_FEDORA:
          requiredRepoPackages = ['dnf-plugins-core']
        elif self.distro == PLATFORM_LINUX_CENTOS:
          requiredRepoPackages = ['yum-utils', 'device-mapper-persistent-data', 'lvm2']
        else:
          requiredRepoPackages = []

        if len(requiredRepoPackages) > 0:
          eprint(f"Installing required packages: {requiredRepoPackages}")
          self.install_package(requiredRepoPackages)

        # install docker via repo if possible
        dockerPackages = []
        if ((self.distro == PLATFORM_LINUX_UBUNTU) or (self.distro == PLATFORM_LINUX_DEBIAN)) and self.codename:

          # for debian/ubuntu, add docker GPG key and check its fingerprint
          if self.debug:
            eprint("Requesting docker GPG key for package signing")
          dockerGpgKey = requests.get(f'https://download.docker.com/linux/{self.distro}/gpg', allow_redirects=True)
          err, out = self.run_process(['apt-key', 'add'], stdin=dockerGpgKey.content.decode(sys.getdefaultencoding()), privileged=True, stderr=False)
          if (err == 0):
            err, out = self.run_process(['apt-key', 'fingerprint', DEB_GPG_KEY_FINGERPRINT], privileged=True, stderr=False)

          # add docker .deb repository
          if (err == 0):
            if self.debug:
              eprint("Adding docker repository")
            err, out = self.run_process(['add-apt-repository', '-y', '-r', f'deb [arch=amd64] https://download.docker.com/linux/{self.distro} {self.codename} stable'], privileged=True)
            err, out = self.run_process(['add-apt-repository', '-y', '-u', f'deb [arch=amd64] https://download.docker.com/linux/{self.distro} {self.codename} stable'], privileged=True)

          # docker packages to install
          if (err == 0):
            dockerPackages.extend(['docker-ce', 'docker-ce-cli', 'containerd.io'])

        elif self.distro == PLATFORM_LINUX_FEDORA:

          # add docker fedora repository
          if self.debug:
            eprint("Adding docker repository")
          err, out = self.run_process(['dnf', 'config-manager', '-y', '--add-repo', 'https://download.docker.com/linux/fedora/docker-ce.repo'], privileged=True)

          # docker packages to install
          if (err == 0):
            dockerPackages.extend(['docker-ce', 'docker-ce-cli', 'containerd.io'])

        elif self.distro == PLATFORM_LINUX_CENTOS:
          # add docker centos repository
          if self.debug:
            eprint("Adding docker repository")
          err, out = self.run_process(['yum-config-manager', '-y', '--add-repo', 'https://download.docker.com/linux/centos/docker-ce.repo'], privileged=True)

          # docker packages to install
          if (err == 0):
            dockerPackages.extend(['docker-ce', 'docker-ce-cli', 'containerd.io'])

        else:
          err, out = None, None

        if len(dockerPackages) > 0:
          eprint(f"Installing docker packages: {dockerPackages}")
          if self.install_package(dockerPackages):
            eprint("Installation of docker packages apparently succeeded")
            result = True
          else:
            eprint("Installation of docker packages failed")

      # the user either chose not to use the official repos, the official repo installation failed, or there are not official repos available
      # see if we want to attempt using the convenience script at https://get.docker.com (see https://github.com/docker/docker-install)
      if not result and InstallerYesOrNo('Docker not installed via official repositories. Attempt to install Docker via convenience script (please read https://github.com/docker/docker-install)?', default=False):
        tempFileName = os.path.join(self.tempDirName, 'docker-install.sh')
        if DownloadToFile("https://get.docker.com/", tempFileName, debug=self.debug):
          os.chmod(tempFileName, 493) # 493 = 0o755
          err, out = self.run_process(([tempFileName]), privileged=True)
          if (err == 0):
            eprint("Installation of docker apparently succeeded")
            result = True
          else:
            eprint(f"Installation of docker failed: {out}")
        else:
          eprint(f"Downloading {dockerComposeUrl} to {tempFileName} failed")

    if result and ((self.distro == PLATFORM_LINUX_FEDORA) or (self.distro == PLATFORM_LINUX_CENTOS)):
      # centos/fedora don't automatically start/enable the daemon, so do so now
      err, out = self.run_process(['systemctl', 'start', 'docker'], privileged=True)
      if (err == 0):
        err, out = self.run_process(['systemctl', 'enable', 'docker'], privileged=True)
        if (err != 0):
          eprint(f"Enabling docker service failed: {out}")
      else:
        eprint(f"Starting docker service failed: {out}")

    # at this point we either have installed docker successfully or we have to give up, as we've tried all we could
    err, out = self.run_process(['docker', 'info'], privileged=True, retry=6, retrySleepSec=5)
    if result and (err == 0):
      if self.debug:
        eprint('"docker info" succeeded')

      # add non-root user to docker group if required
      usersToAdd = []
      if self.scriptUser == 'root':
        while InstallerYesOrNo(f"Add {'a' if len(usersToAdd) == 0 else 'another'} non-root user to the \"docker\" group?"):
          tmpUser = InstallerAskForString('Enter user account')
          if (len(tmpUser) > 0): usersToAdd.append(tmpUser)
      else:
        usersToAdd.append(self.scriptUser)

      for user in usersToAdd:
        err, out = self.run_process(['usermod', '-a', '-G', 'docker', user], privileged=True)
        if (err == 0):
          if self.debug:
            eprint(f'Adding {user} to "docker" group succeeded')
        else:
          eprint(f'Adding {user} to "docker" group failed')

    elif (err != 0):
      result = False

    return result

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def install_docker_compose(self):
    result = False

    dockerComposeCmd = 'docker-compose'
    if not Which(dockerComposeCmd, debug=self.debug) and os.path.isfile('/usr/local/bin/docker-compose'):
      dockerComposeCmd = '/usr/local/bin/docker-compose'

    # first see if docker-compose is already installed and runnable (try non-root and root)
    err, out = self.run_process([dockerComposeCmd, 'version'], privileged=False)
    if (err != 0):
      err, out = self.run_process([dockerComposeCmd, 'version'], privileged=True)

    if (err != 0) and InstallerYesOrNo('"docker-compose version" failed, attempt to install docker-compose?', default=False):

      if InstallerYesOrNo('Install docker-compose directly from docker github?', default=False):
        # download docker-compose from github and put it in /usr/local/bin

        # need to know some linux platform info
        unames = []
        err, out = self.run_process((['uname', '-s']))
        if (err == 0) and (len(out) > 0): unames.append(out[0])
        err, out = self.run_process((['uname', '-m']))
        if (err == 0) and (len(out) > 0): unames.append(out[0])
        if len(unames) == 2:
          # download docker-compose from github and save it to a temporary file
          tempFileName = os.path.join(self.tempDirName, dockerComposeCmd)
          dockerComposeUrl = f"https://github.com/docker/compose/releases/download/{dockerComposeInstallVersion}/docker-compose-{unames[0]}-{unames[1]}"
          if DownloadToFile(dockerComposeUrl, tempFileName, debug=self.debug):
            os.chmod(tempFileName, 493) # 493 = 0o755, mark as executable
            # put docker-compose into /usr/local/bin
            err, out = self.run_process((['cp', '-f', tempFileName, '/usr/local/bin/docker-compose']), privileged=True)
            if (err == 0):
              eprint("Download and installation of docker-compose apparently succeeded")
              dockerComposeCmd = '/usr/local/bin/docker-compose'
            else:
              raise Exception(f'Error copying {tempFileName} to /usr/local/bin: {out}')

          else:
            eprint(f"Downloading {dockerComposeUrl} to {tempFileName} failed")

      elif InstallerYesOrNo('Install docker-compose via pip?', default=True):
        err, out = self.run_process(self.installPipPackageCmds + ['docker-compose'])
        if (err == 0):
          eprint(f"Installation of docker-compose apparently succeeded")
        else:
          eprint(f"Install docker-compose via pip failed with {err}, {out}")

    # see if docker-compose is now installed and runnable (try non-root and root)
    err, out = self.run_process([dockerComposeCmd, 'version'], privileged=False)
    if (err != 0):
      err, out = self.run_process([dockerComposeCmd, 'version'], privileged=True)

    if (err == 0):
      result = True
      if self.debug:
        eprint('"docker-compose version" succeeded')

    return result

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
      eprint('Docker can be installed and maintained with Homebrew, or manually.')
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

    self.macBrewDockerPackage = 'docker-edge'
    self.macBrewDockerSettingsFile = '/Users/{}/Library/Group Containers/group.com.docker/settings.json'

    if self.pyExecUserOwned:
      # we're running a user-owned python, regular pip should work
      self.installPipPackageCmds = self.pipCmd + ['install']
    else:
      # python is owned by system, so make sure to pass the --user flag
      self.installPipPackageCmds = self.pipCmd + ['install', '--user']

    self.pipPackages.extend(['Cython', 'psutil'])

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  def install_docker(self):
    result = False

    # first see if docker is already installed/runnable
    err, out = self.run_process(['docker', 'info'])

    if (err != 0) and self.useBrew and self.package_is_installed(self.macBrewDockerPackage):
      # if docker is installed via brew, but not running, prompt them to start it
      eprint(f'{self.macBrewDockerPackage} appears to be installed via Homebrew, but "docker info" failed')
      while True:
        response = InstallerAskForString('Starting Docker the first time may require user interaction. Please find and start Docker in the Applications folder, then return here and type YES').lower()
        if (response == 'yes'):
          break
      err, out = self.run_process(['docker', 'info'], retry=12, retrySleepSec=5)

    # did docker info work?
    if (err == 0):
      result = True

    elif InstallerYesOrNo('"docker info" failed, attempt to install Docker?', default=False):

      if self.useBrew:
        # install docker via brew cask (requires user interaction)
        dockerPackages = [self.macBrewDockerPackage]
        eprint(f"Installing docker packages: {dockerPackages}")
        if self.install_package(dockerPackages):
          eprint("Installation of docker packages apparently succeeded")
          while True:
            response = InstallerAskForString('Starting Docker the first time may require user interaction. Please find and start Docker in the Applications folder, then return here and type YES').lower()
            if (response == 'yes'):
              break
        else:
          eprint("Installation of docker packages failed")

      else:
        # install docker via downloaded dmg file (requires user interaction)
        dlDirName = f'/Users/{self.scriptUser}/Downloads'
        if os.path.isdir(dlDirName):
          tempFileName = os.path.join(dlDirName, 'Docker.dmg')
        else:
          tempFileName = os.path.join(self.tempDirName, 'Docker.dmg')
        if DownloadToFile('https://download.docker.com/mac/edge/Docker.dmg', tempFileName, debug=self.debug):
          while True:
            response = InstallerAskForString(f'Installing and starting Docker the first time may require user interaction. Please open Finder and install {tempFileName}, start Docker from the Applications folder, then return here and type YES').lower()
            if (response == 'yes'):
              break

      # at this point we either have installed docker successfully or we have to give up, as we've tried all we could
      err, out = self.run_process(['docker', 'info'], retry=12, retrySleepSec=5)
      if (err == 0):
        result = True
        if self.debug:
          eprint('"docker info" succeeded')

      elif (err != 0):
        raise Exception(f'{ScriptName} requires docker edge, please see {DOCKER_INSTALL_URLS[self.platform]}')

    elif (err != 0):
      raise Exception(f'{ScriptName} requires docker edge, please see {DOCKER_INSTALL_URLS[self.platform]}')

    # tweak CPU/RAM usage for Docker in Mac
    settingsFile = self.macBrewDockerSettingsFile.format(self.scriptUser)
    if result and os.path.isfile(settingsFile) and InstallerYesOrNo(f'Configure Docker resource usage in {settingsFile}?', default=True):

      # adjust CPU and RAM based on system resources
      if self.totalCores >= 16:
        newCpus = 12
      elif self.totalCores >= 12:
        newCpus = 8
      elif self.totalCores >= 8:
        newCpus = 6
      elif self.totalCores >= 4:
        newCpus = 4
      else:
        newCpus = 2

      if self.totalMemoryGigs >= 64.0:
        newMemoryGiB = 32
      elif self.totalMemoryGigs >= 32.0:
        newMemoryGiB = 24
      elif self.totalMemoryGigs >= 24.0:
        newMemoryGiB = 16
      elif self.totalMemoryGigs >= 16.0:
        newMemoryGiB = 12
      elif self.totalMemoryGigs >= 8.0:
        newMemoryGiB = 8
      elif self.totalMemoryGigs >= 4.0:
        newMemoryGiB = 4
      else:
        newMemoryGiB = 2

      while not InstallerYesOrNo(f"Setting {newCpus if newCpus else '(unchanged)'} for CPU cores and {newMemoryGiB if newMemoryGiB else '(unchanged)'} GiB for RAM. Is this OK?", default=True):
        newCpus = InstallerAskForString('Enter Docker CPU cores (e.g., 4, 8, 16)')
        newMemoryGiB = InstallerAskForString('Enter Docker RAM MiB (e.g., 8, 16, etc.)')

      if newCpus or newMemoryMiB:
        with open(settingsFile, 'r+') as f:
          data = json.load(f)
          if newCpus: data['cpus'] = int(newCpus)
          if newMemoryGiB: data['memoryMiB'] = int(newMemoryGiB)*1024
          f.seek(0)
          json.dump(data, f, indent=2)
          f.truncate()

        # at this point we need to essentially update our system memory stats because we're running inside docker
        # and don't have the whole banana at our disposal
        self.totalMemoryGigs = newMemoryGiB

        eprint("Docker resource settings adjusted, attempting restart...")

        err, out = self.run_process(['osascript', '-e', 'quit app "Docker"'])
        if (err == 0):
          time.sleep(5)
          err, out = self.run_process(['open', '-a', 'Docker'])

        if (err == 0):
          err, out = self.run_process(['docker', 'info'], retry=12, retrySleepSec=5)
          if (err == 0):
            if self.debug:
              eprint('"docker info" succeeded')

        else:
          eprint(f"Restarting Docker automatically failed: {out}")
          while True:
            response = InstallerAskForString('Please restart Docker via the system taskbar, then return here and type YES').lower()
            if (response == 'yes'):
              break

    return result

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

  if not DoDynamicImport('requests', 'requests', debug=args.debug):
    exit(2)
  if not DoDynamicImport('git', 'GitPython', debug=args.debug):
    exit(2)

  if args.debug:
    if args.configOnly:
      eprint("Only doing configuration, not installation")

  installerPlatform = platform.system()
  if installerPlatform == PLATFORM_LINUX:
    installer = LinuxInstaller(debug=args.debug, configOnly=args.configOnly)
  elif installerPlatform == PLATFORM_MAC:
    installer = MacInstaller(debug=args.debug, configOnly=args.configOnly)
  elif installerPlatform == PLATFORM_WINDOWS:
    raise Exception(f'{ScriptName} is not yet supported on {installerPlatform}')
    installer = WindowsInstaller(debug=args.debug, configOnly=args.configOnly)

  success = False
  installPath = None

  if (not args.configOnly):
    if hasattr(installer, 'install_required_packages'): success = installer.install_required_packages()
    if hasattr(installer, 'setup_sources'): success = installer.setup_sources()
    if hasattr(installer, 'install_docker'): success = installer.install_docker()
    if hasattr(installer, 'install_docker_compose'): success = installer.install_docker_compose()

  if (hasattr(installer, 'install_pip_packages') and InstallerYesOrNo('Install common pip packages?', default=False)):
    success = installer.install_pip_packages()

if __name__ == '__main__':
  main()
