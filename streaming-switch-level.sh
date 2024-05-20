#!/bin/sh
# Run this script with no arguments to see alternatives
ROOT=`dirname $0`
if [ "$1" = "current" -o x"$1" = "x" ]; then
  if [ -r "$ROOT"/packages/streaming/current ]; then
    echo "Current streaming service implementation is:"
    ls -l "$ROOT"/packages/streaming/current| awk '-F -> ' '{print $2}'
  else
    echo "\n\n**** No streaming service implementation is currently selected. Build will fail."
    echo "  Please select an implementation, e.g.:"
    echo "  $0 level3"
    echo ""
  fi
  echo "Available streaming service implementations are:"
  ls "$ROOT"/packages/streaming/*/package-meta-data.xml | grep -v current| awk '-Fpackages/streaming/|/package-meta-data.xml' '{print $2}'
else
  if [ -r "$ROOT"/packages/streaming/$1/package-meta-data.xml ]; then
    rm -f "$ROOT"/packages/streaming/current
    ln -s "$1" "$ROOT"/packages/streaming/current
    echo -n "Set streaming service implementation to: "
    ls -l "$ROOT"/packages/streaming/current| awk '-F -> ' '{print $2}'
  else
    echo "'$1' is not a directory containing a streaming service implementation. Aborted."
  fi
fi
