#!/bin/bash

if [ -a /proc/cpuinfo ]; then
# Linux
CPU_CORES_COUNT=$(expr $(grep 'processor' /proc/cpuinfo | wc -l) + 1)
else
# Mac
CPU_CORES_COUNT=$(expr $(sysctl -A 2>&1 |grep 'hw\.ncpu:' |sed "s/^hw\.ncpu: \([0-9]*\)/\1/") + 1)
fi

export CPU_CORES_COUNT
echo "CPU_CORES_COUNT=$CPU_CORES_COUNT"
