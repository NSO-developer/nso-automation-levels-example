PKG_COMPONENTS := load-dir package-meta-data.xml python src templates

# default streaming service starting point directory
DEST ?= my-streaming

all: build start

build: build-packages netsim

start: start-netsims start-nso start-cli

build-packages: build-services

build-neds:
	@for p in `grep -l ned-id packages/*/src/package-meta-data.xml.in`; do n=`dirname $$p`; echo "\n#### Building NED `dirname $$n`"; make -C $$n || exit; done

help:
usage:
	@echo
	@echo "Need to select a streaming service:"
	@echo
	@echo "Use one of the predefined solutions:"
	@echo
	@echo "    make streaming-level3"
	@echo "    make streaming-level4"
	@echo "    make streaming-level5"
	@echo
	@echo "Use your own solution as a starting point:"
	@echo
	@echo "    make START=level3 my-streaming-current"
	@echo "    make START=level3 DEST=my-level3 my-streaming-current"
	@echo

error-usage:
	@make usage
	@exit 1

packages/streaming/src:
	@make usage
	@test -d $@ || exit 1

unset-current-streaming:
	rm -f packages/streaming/current
	for f in $(PKG_COMPONENTS); do rm -f packages/streaming/$$f; done

set-current-streaming:
	ln -s $(DEST) packages/streaming/current
	for f in $(PKG_COMPONENTS); do ln -s $(DEST)/$$f packages/streaming/$$f; done

streaming-level3:
	make DEST=level3 set-current-streaming
streaming-level4:
	make DEST=level4 set-current-streaming
streaming-level5:
	make DEST=level5 set-current-streaming

my-streaming-current:
	if [ "x" = x"$(START)" -o ! -d "packages/streaming/$(START)" ]; then \
		make error-usage ; \
	fi
	cp -a "packages/streaming/$(START)" "packages/streaming/$(DEST)"
	make unset-current-streaming set-current-streaming


build-services: build-neds packages/streaming/src
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
