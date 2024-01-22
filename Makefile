all: build start

build: build-packages netsim

start: start-netsims start-nso start-cli

build-packages: build-services

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
	@ncs_cmd -u admin -c 'maction /ncs:devices/sync-from'
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
	@-rm ncs-cdb/netsim-init.xml
	@ncs-setup --reset
