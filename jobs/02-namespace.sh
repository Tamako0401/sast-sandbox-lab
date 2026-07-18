#!/bin/sh
set -eu

echo '== namespace observation job =='
echo "hostname before: $(hostname)"
hostname sast-box
echo "hostname after:  $(hostname)"

echo '== processes visible in the box =='
ps -ef

echo '== /proc mount visible in the box =='
mount | grep ' on /proc '

echo '== PID 1 status =='
grep -E '^(Name|Pid|PPid|NSpid):' /proc/1/status

