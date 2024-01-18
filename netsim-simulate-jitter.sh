#!/bin/sh
ncs_cmd -c "dbset operational; mtrans; mset /streaming:dc{$1}/oper-status/jitter $2;" && echo "Set jitter for $1 to $2"
exit 0