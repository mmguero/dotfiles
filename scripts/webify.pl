#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Copy;
use File::Basename;

my $targetHeight  = 600;
my $targetQuality = 80;
my $targetDpi     = 72;
my $overwrite     = 0;
my $dryRun        = 0;

my %opts = ();
GetOptions("overwrite!"=>\$opts{overwrite},
           "dry!"=>\$opts{dry},
           "height=i"=> \$opts{height},
           "quality=i"=> \$opts{quality},
           "dpi=i"=> \$opts{dpi}) or die "Invalid options";
$targetHeight = $opts{height} if (defined $opts{height} && ($opts{height} =~ /^\d+$/));
$targetQuality = $opts{quality} if (defined $opts{quality} && ($opts{quality} =~ /^\d+$/));
$targetDpi = $opts{dpi} if (defined $opts{dpi} && ($opts{dpi} =~ /^\d+$/));
$overwrite = 1 if (defined $opts{overwrite});
$dryRun = 1 if (defined $opts{dry});

print STDERR "targetHeight: ".$targetHeight."\n";
print STDERR "targetQuality: ".$targetQuality."\n";
print STDERR "targetDpi: ".$targetDpi."\n";
print STDERR "overwrite: ".$overwrite."\n";
print STDERR "dryRun: ".$dryRun."\n";

foreach my $arg (@ARGV) {

  # make sure file exists
  if (-e $arg) {
  
    # split into parts
    my $filename = '';
    my $filepath = '';
    my $fileext  = '';
    ($filename, $filepath, $fileext) = fileparse($arg, '\..*');
  
    # rename extension to lower case
    if ($fileext ne lc($fileext)) {
      $fileext = lc($fileext);
      print STDERR "Renaming ".$arg." to ".$filepath.$filename.$fileext."\n";
      move($arg, $filepath.$filename.$fileext) unless $dryRun;
      $arg = $filepath.$filename.$fileext unless $dryRun;
    }
    
    # put together arguments for ImageMagick
    my @cmd = ();
    if ($overwrite) {
      push(@cmd, 'mogrify');
    } else {
      push(@cmd, 'convert');    
    }
    push(@cmd, '-density', $targetDpi."x".$targetDpi);
    push(@cmd, '-geometry', "x".$targetHeight);
    push(@cmd, '-quality', $targetQuality."%");
    push(@cmd, $arg);
    push(@cmd, $filepath.$filename."_resized".$fileext) unless ($overwrite);
    
    print STDERR join(' ', @cmd)."\n";
    unless ($dryRun) {
      if (system(@cmd) != 0) {
        my $exitValue  = $? >> 8;
        my $signalNum  = $? & 127;
        my $dumpedCore = $? & 128;
        print STDERR "Command failed, exit value: ".$exitValue."\n";
      }
    }
    
  } else {
    print STDERR "$arg does not exist!\n";
  }
}
