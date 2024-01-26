# NSO Automation Levels Example
# (C) 2024 Cisco Systems
# Permission to use this code as a starting point hereby granted

NSO_VERSION = $(shell ncs --version)

top: check-level
	@echo "Using NSO version: $(NSO_VERSION)"
	@echo
	@echo "Makefile rules (the most used):"
	@echo " * all              Build and start everything with the currently selected streaming service"
	@echo " * build            Build all packages and create the NETSIM devices"
	@echo " * build-packages   Build all packages"
	@echo " * start            Start the NETSIMs, NSO and enter the NSO CLI"
	@echo " * stop             Stop NSO and the NETSIM devices"
	@echo " * clean            Stop NSO, the NETSIM devices, clean all build files, and reset the config database"

all: check-level build start

build: build-packages netsim

start: start-netsims start-nso start-cli

build-packages: build-services

check-level: packages/streaming/current
ifeq "$(NCS_DIR)" ""
	$(error Environment variable NCS_DIR is not set. Source ncsrc to setup NSO environment before proceeding)
endif
	@echo "\n#### Streaming service implementation selection"
	@./streaming-switch-level.sh

packages/streaming/current:
	@echo "\n#### Streaming service implementation not selected"
	@echo "Before we begin, you need to select implementation of the streaming service"
	@echo "See the README file for more information"
	@echo ""
	@echo " - You may select one of the existing implementations. For example:"
	@echo "   ./streaming-switch-level.sh level5"
	@echo ""
	@echo " - You may create an implementation of your own, then select that one. For example:"
	@echo "   cp -r packages/streaming/level3 packages/streaming/myway"
	@echo "   ./streaming-switch-level.sh myway"
	@echo ""
	@false

build-neds:
	@for p in `grep -l ned-id packages/*/src/package-meta-data.xml.in`; do n=`dirname $$p`; echo "\n#### Building NED `dirname $$n`"; make -C $$n || exit; done

build-services: build-neds
	@for n in packages/streaming; do echo "\n#### Building Service $$n"; make -C $$n/src || exit; done

netsim:
	@echo "\n#### Building netsim network"
	@if [ ! -d netsim ]; then                              \
		ncs-netsim                                           \
			create-network packages/origin     2 origin        \
			create-network packages/firewall   2 fw            \
			create-network packages/edge       4 edge;         \
		ncs-netsim add-device packages/skylight skylight;    \
		ncs-netsim ncs-xml-init > ncs-cdb/netsim-init.xml;   \
	else echo "\n#### Netsim network already created";     \
	fi

start-netsims: netsim
	@echo "\n#### Starting netsim network"
	@ncs-netsim is-alive origin0 | grep "DEVICE origin0 OK"; if [ $$? = 0 ]; then echo "NETSIM network already running"; else ncs-netsim -a start; fi

start-nso: ncs.conf
	@echo "\n#### Starting NSO"
	@ncs --status > /dev/null 2>&1; if [ $$? = 0 ]; then echo "NSO already running, but if you updated any packages, you need to reload them inside NSO: packages reload"; else ncs -c ncs.conf --with-package-reload; fi
	@./netsim-simulate-jitter.sh dc0 20
	@./netsim-simulate-jitter.sh dc1 25
	@./netsim-simulate-energy-price.sh dc0 100
	@./netsim-simulate-energy-price.sh dc1 75
	@echo "\n#### Syncing-from all devices"
	@ncs_cmd -u admin -c 'maction /ncs:devices/sync-from' | grep -v sync-result | grep -v "result true"
	@ncs_cmd -u admin -c 'mset /ncs:devices/ncs:device{"origin0"}/ncs:read-timeout 60; mset /ncs:devices/ncs:device{"origin1"}/ncs:read-timeout 60;'
	@ncs_load -u admin -lm edge_init.xml

start-cli:
	@echo "\n#### Entering NSO Command Line Interface as user admin"
	-ncs_cli -Cu admin

stop:
	@if [ -d netsim ]; then ncs-netsim -a stop; echo "NETSIM network stopped"; else echo "NETSIM already stopped"; fi;
	@ncs --status > /dev/null 2>&1; if [ $$? = 0 ]; then ncs --stop; echo "NSO stopped"; else echo "NSO already stopped"; fi

clean: stop
	@for p in packages/*; do echo "\n#### Cleaning $$p"; make -C $$p/src clean; done
	@rm -rf netsim
	@-rm -f ncs-cdb/netsim-init.xml
	@-rm -rf ncs-cdb/*.cdb ncs-cdb/rollback* logs/* state/* # this is what "ncs-setup --reset" does
