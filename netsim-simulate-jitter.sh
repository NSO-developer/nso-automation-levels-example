#!/bin/sh
echo "Setting jitter for $1 to $2"
ncs_cmd -c "dbset operational; mtrans; mset /streaming:dc{$1}/oper-status/jitter $2;"
