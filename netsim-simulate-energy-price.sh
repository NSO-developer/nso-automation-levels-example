#!/bin/sh

usage() {
  echo "usage: $0 [-h] | dc energy-price"
}

if [ "$NCS_DIR" == "" ]; then
  echo "ERROR: NCS_DIR is not setup. Source ncsrc to setup NSO environment before proceeding"
  exit 1
fi

if [ $# -lt 2 ]; then
  usage
  exit 1
fi
ncs_cmd -c "dbset operational; mtrans; mset /streaming:dc{$1}/oper-status/energy-price $2;" 2>/dev/null && echo "Set energy-price for $1 to $2"

exit 0
