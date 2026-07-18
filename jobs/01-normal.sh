#!/bin/sh
set -eu

echo '== normal job =='
echo "hostname: $(hostname)"
echo "working directory: $(pwd)"
echo "architecture: $(uname -m)"
id
cat /etc/os-release
echo 'normal job finished'

