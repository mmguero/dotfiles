#!/usr/bin/perl

use warnings;
use strict;

use Switch;
use Proc::Daemon;

sub get_cpu_info($) {
  my $sleep_sec = shift;

  my $tmp1_cpu_user=`grep -m1 '^cpu' /proc/stat|awk '{print \$2}'`;
  my $tmp1_cpu_nice=`grep -m1 '^cpu' /proc/stat|awk '{print \$3}'`;
  my $tmp1_cpu_sys=`grep -m1 '^cpu' /proc/stat|awk '{print \$4}'`;
  my $tmp1_cpu_idle=`grep -m1 '^cpu' /proc/stat|awk '{print \$5}'`;
  my $tmp1_cpu_iowait=`grep -m1 '^cpu' /proc/stat|awk '{print \$6}'`;
  my $tmp1_cpu_irq=`grep -m1 '^cpu' /proc/stat|awk '{print \$7}'`;
  my $tmp1_cpu_softirq=`grep -m1 '^cpu' /proc/stat|awk '{print \$8}'`;
  my $tmp1_cpu_total= $tmp1_cpu_user + $tmp1_cpu_nice + $tmp1_cpu_sys + $tmp1_cpu_idle + $tmp1_cpu_iowait + $tmp1_cpu_irq + $tmp1_cpu_softirq;

  sleep $sleep_sec;

  my $tmp2_cpu_user=`grep -m1 '^cpu' /proc/stat|awk '{print \$2}'`;
  my $tmp2_cpu_nice=`grep -m1 '^cpu' /proc/stat|awk '{print \$3}'`;
  my $tmp2_cpu_sys=`grep -m1 '^cpu' /proc/stat|awk '{print \$4}'`;
  my $tmp2_cpu_idle=`grep -m1 '^cpu' /proc/stat|awk '{print \$5}'`;
  my $tmp2_cpu_iowait=`grep -m1 '^cpu' /proc/stat|awk '{print \$6}'`;
  my $tmp2_cpu_irq=`grep -m1 '^cpu' /proc/stat|awk '{print \$7}'`;
  my $tmp2_cpu_softirq=`grep -m1 '^cpu' /proc/stat|awk '{print \$8}'`;
  my $tmp2_cpu_total=$tmp2_cpu_user + $tmp2_cpu_nice + $tmp2_cpu_sys + $tmp2_cpu_idle + $tmp2_cpu_iowait + $tmp2_cpu_irq + $tmp2_cpu_softirq;

  my $diff_cpu_user=${tmp2_cpu_user} - ${tmp1_cpu_user};
  my $diff_cpu_nice=${tmp2_cpu_nice} - ${tmp1_cpu_nice};
  my $diff_cpu_sys=${tmp2_cpu_sys} - ${tmp1_cpu_sys};
  my $diff_cpu_idle=${tmp2_cpu_idle} - ${tmp1_cpu_idle};
  my $diff_cpu_iowait=${tmp2_cpu_iowait} - ${tmp1_cpu_iowait};
  my $diff_cpu_irq=${tmp2_cpu_irq} - ${tmp1_cpu_irq};
  my $diff_cpu_softirq=${tmp2_cpu_softirq} - ${tmp1_cpu_softirq};
  my $diff_cpu_total=${tmp2_cpu_total} - ${tmp1_cpu_total};

  my $cpu_user=(1000*${diff_cpu_user}/${diff_cpu_total}+5)/10;
  my $cpu_nice=(1000*${diff_cpu_nice}/${diff_cpu_total}+5)/10;
  my $cpu_sys=(1000*${diff_cpu_sys}/${diff_cpu_total}+5)/10;
  my $cpu_iowait=(1000*${diff_cpu_iowait}/${diff_cpu_total}+5)/10;
  my $cpu_irq=(1000*${diff_cpu_irq}/${diff_cpu_total}+5)/10;
  my $cpu_softirq=(1000*${diff_cpu_softirq}/${diff_cpu_total}+5)/10;
  my $cpu_total=(1000*${diff_cpu_total}/${diff_cpu_total}+5)/10;
  my $cpu_usage=(${cpu_user}+${cpu_nice}+${cpu_sys}+${cpu_iowait}+${cpu_irq}+${cpu_softirq})/1;
  my $cpu_idle=(1000*${diff_cpu_idle}/${diff_cpu_total}+5)/10;
  
  my %cpu_info_hash = (cpu_user => $cpu_user,
                       cpu_nice => $cpu_nice,
                       cpu_sys => $cpu_sys,
                       cpu_iowait => $cpu_iowait,
                       cpu_irq => $cpu_irq,
                       cpu_softirq => $cpu_softirq,
                       cpu_total => $cpu_total,
                       cpu_usage => $cpu_usage,
                       cpu_idle => $cpu_idle);

  return %cpu_info_hash;
}

Proc::Daemon::Init;

my $continue = 1;
$SIG{TERM} = sub { $continue = 0 };

my $cmd_prefix = '';
$cmd_prefix = 'sudo ' if ($ENV{USER} ne 'root');

my $old_color = "";
my $color = "";
while ($continue) {
  my %cpu_info_hash = get_cpu_info(1);
  switch (int($cpu_info_hash{cpu_usage})) {
    case ([0..9])   { $color = 'white' }
    case ([10..19]) { $color = 'blue' }
    case ([20..39]) { $color = 'green' }
    case ([40..59]) { $color = 'yellow' }
    case ([60..79]) { $color = 'orange' }
    else            { $color = 'red' }
  }  
  `$cmd_prefix /usr/local/bin/afx --all=$color` if ($old_color ne $color);
  $old_color = $color;
  sleep 5;
}
`$cmd_prefix /usr/local/bin/afx --all=black`;

