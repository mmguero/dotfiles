#!/usr/bin/perl

use HTML::TreeBuilder;
use File::Copy;

use warnings;
use strict;

foreach my $file (@ARGV) {
  chomp $file;
  print "Parsing $file\n";
  my $outFile = $file.".new";
  my $tree = HTML::TreeBuilder->new();
  $tree->no_space_compacting(1);
  $tree->parse_file($file) or die $!;
  print "Scanning $file\n";

  my @elements;

   @elements = $tree->look_down('_tag' => 'script');
   if (@elements) {
     foreach my $element (@elements) {
       if ($element->tag()) {
         print "Found ".$element->tag()." element\n";
         $element->delete;
       }
     }
   }

  @elements = $tree->look_down('_tag' => 'div', class => qr/^\s*(cap-top|footer-outer|post-footer|header-outer|blog-pager|blog-feeds|navbar\s+section|content|(content|body)-fauxcolumns)\s*$/i);
  if (@elements) {
  foreach my $element (@elements) {
      if ($element->tag()) {
        print "Found ".$element->tag()."->".$element->attr('class')." element\n";
        $element->delete;
      }
    }
  }
  
   @elements = $tree->look_down('_tag' => 'h2', class => 'date-header');
   if (@elements) {
     foreach my $element (@elements) {
       if ($element->tag()) {
         print "Found ".$element->tag()."->".$element->attr('class')." element\n";
         $element->delete;
       }
     }
   }
 
  @elements = $tree->look_down('_tag' => 'a', href => 'javascript:void(0)');
   if (@elements) {
     foreach my $element (@elements) {
       if ($element->tag()) {
         print "Found ".$element->tag()."->".$element->attr('href')." element\n";
         $element->delete;
       }
     }
   }

  print "Saving $outFile\n";
  open(OUT, ">$outFile") || die "Can't write: $!";
  print OUT $tree->as_HTML;
  close(OUT);
  $tree->delete; # done with it, so delete it
 
  my $oldFile = $file.".orig";
  move ($file, $oldFile) or die $!;
  move ($outFile, $file) or die $!;
}