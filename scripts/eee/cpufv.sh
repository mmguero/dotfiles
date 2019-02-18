#!/bin/bash

if [ ! -z $1 ]
then
  echo $1 > /sys/devices/platform/eeepc/cpufv
fi

cat /sys/devices/platform/eeepc/cpufv

