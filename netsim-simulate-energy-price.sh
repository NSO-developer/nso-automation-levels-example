#!/bin/sh
echo "Setting energy-price for $1 to $2"
ncs_cmd -c "dbset operational; mtrans; mset /streaming:dc{$1}/oper-status/energy-price $2;"
