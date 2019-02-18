#!/usr/bin/perl

my $threshold = 8;

sub round {
    my ($number) = shift;
    return int($number + .5);
}

foreach my $file (@ARGV) {
  chomp $file;
  my $wav_file = $file.".wav";
  my $mp3_file = $file.".mp3";
  if ($file =~ /\.avi$/) {
    my $length = `mplayer -vo dummy -ao dummy -identify $file 2>/dev/null`;
    if ($length =~ /ID_LENGTH=([\d\.]+)/) {
      $length = round($1);
      if ($length >= $threshold) {
        if (-e $wav_file) {
          `lame $wav_file $mp3_file`;
          unlink($wav_file);
        }
      } else {
        unlink($file);
        if (-e $wav_file) {
          unlink($wav_file);
        }
      }
    }
  }
}
