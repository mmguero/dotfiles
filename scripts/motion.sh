#!/usr/bin/perl

use warnings;
use strict;

my $pid = fork();
if ($pid) {
  # parent, do nothing...
} elsif (defined($pid)) {
  # child, run motion in the background
  open STDERR, '>/dev/null';
  open STDOUT, '>/dev/null';
  my $cmd = "/usr/bin/motion -c /home/tlacuache/.motion";
  exec $cmd;
} else {
  # fork failed
  die "fork failed";
}

