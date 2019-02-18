#!/usr/bin/perl

use warnings;
use strict;

my $oldval = `/usr/local/bin/cpufv.sh`;
chomp $oldval;
my $sel_0 = "0 - performance";
my $sel_1 = "1 - default";
my $sel_2 = "2 - powersave";
my $user_sel = `zenity --title "set cpufv value" --text "Old value was $oldval, please select:" --list --radiolist --column "Setting" --column "Value" False "$sel_0" True "$sel_1" False "$sel_2"`;
chomp $user_sel;
$user_sel =~ s/(\d+).*/$1/;
if ($user_sel =~ /^(0|1|2)$/) {
  `gksu /usr/local/bin/cpufv.sh $user_sel`;
}

