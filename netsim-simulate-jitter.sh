#!/bin/sh

usage() {
  echo "usage: $0 [-h] | <dc> <jitter>"
}

if [ -z "$NCS_DIR" ]; then
  echo "ERROR: Environment variable NCS_DIR is not set. Source ncsrc to setup NSO environment before proceeding"
  exit 1
fi

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

ncs_cmd -c "dbset operational; mtrans; mset /streaming:dc{$1}/oper-status/jitter $2;" 2>/dev/null && echo "Set jitter for $1 to $2"
exit 0
