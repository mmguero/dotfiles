#!/usr/bin/perl

use HTML::TreeBuilder;
use File::Copy;

use warnings;
use strict;

my ($templateFile, $outFile, @inFiles) = @ARGV;
my $inFileCount = @inFiles;
if (($inFileCount == 1) and (-d $inFiles[0])) {
  @inFiles = <$inFiles[0]/*.html>;
}
foreach my $tmpFile (@inFiles) {
  chomp $tmpFile;
  print "$tmpFile\n";
}

if ((!$templateFile) || ($templateFile eq "") || (!(-f $templateFile))) {
  die "Template file does not exist"
}

print "Parsing $templateFile\n";
my $templateTree = HTML::TreeBuilder->new();
$templateTree->no_space_compacting(1);
$templateTree->parse_file($templateFile) or die $!;
print "Scanning $templateFile\n";

my @templateBodyElements;
my $templateBody = undef;
my @inBodyElements;

@templateBodyElements = $templateTree->look_down('_tag' => 'body');
if (@templateBodyElements) {
  foreach my $element (@templateBodyElements) {
    if ($element->tag()) {
      $templateBody = $element;
      print "Found ".$element->tag()." element in template\n";
      last;
    }
  }
} else {
  die "Could not find <body> in template";
}

if ($templateBody) {
  foreach my $file (@inFiles) {
    if (-f $file) {
      print "Parsing $file\n";
      my $inTree = HTML::TreeBuilder->new();
      $inTree->no_space_compacting(1);
      $inTree->parse_file($file) or die $!;
      print "Scanning $file\n";

      @inBodyElements = $inTree->look_down('_tag' => 'body');
      if (@inBodyElements) {
        foreach my $element (@inBodyElements) {
          if ($element->tag()) {
            print "Found ".$element->tag()." element in template\n";
            my @bodyContents = $element->content_list();
            my @bodyCopy = HTML::Element->clone_list(@bodyContents);
            $templateBody->push_content(@bodyCopy);
            last;
          }
        }
      }

      $inTree->delete;
    }
  }
}

print "Saving $outFile\n";
open(OUT, ">$outFile") || die "Can't write: $!";
print OUT $templateTree->as_HTML;
close(OUT);
$templateTree->delete; # done with it, so delete it
