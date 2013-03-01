#!/bin/bash

SELF_CALL=$0
SED_EXPR=$1
DIR=$2

for filename in $DIR
do
echo "Processing $filename"
if [[ -d $filename ]]; then
  echo "$filename is a directory, recursing..."
  $SELF_CALL '$SED_EXPR' $filename
elif [[ -f $filename ]]; then
  echo "sed $SED_EXPR $filename 1> $filename"
  sed SED_EXPR $filename 1> $filename
fi
done
