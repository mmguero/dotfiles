#!/usr/bin/perl

use File::Copy;
use File::Basename;
use File::Spec;

use warnings;
use strict;

sub mkdirp($);

sub mkdirp($) {
  my $dir = shift;
  return if (-d $dir);
  mkdirp(dirname($dir));
  mkdir $dir;
}

foreach my $fileName (@ARGV) {
  chomp $fileName;
  my $absFileName = File::Spec->rel2abs($fileName);
  my @exifInfo = `exifprobe -L "$absFileName"`;
  my $iso = '';
  my $time = '';
  foreach my $line (@exifInfo) {
    chomp $line;
    if ($line =~ /ISOSetting.*=\s*(\S+)/i) {
      $iso = $1;
      $iso =~ s/,//g;
      $iso =~ s/^0+//g;
    } elsif ($line =~ /ExposureTime.*=\s*(\S+)/i) {
      $time = $1;
    }
  }
  if (($iso =~ /^\d+$/) && ($time =~ /^[\d\.]+$/)) {
    my ($volume,$directories,$file) = File::Spec->splitpath($absFileName);
    print "$directories has $file ISO=$iso Time=$time\n";
    my $destDir = $directories.$iso."_".$time;
    mkdirp($destDir);
    if (-d $destDir) {
      move($absFileName, $destDir);
    }
  }
}