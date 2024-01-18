#!/bin/sh
ncs_cmd -c "dbset operational; mtrans; mset /streaming:dc{$1}/oper-status/energy-price $2;" 2>/dev/null && echo "Set energy-price for $1 to $2"
exit 0