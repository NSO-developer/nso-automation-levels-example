# Mandatory targets
TEST_PACKAGE_STORE=../../

all: build
	lux devices.lux

build: netsim ncs packages

ncs:
	ncs-setup --dest . --netsim-dir ./netsim
	sed 's|>\./|>$(PWD)/|g' ncs.conf | \
		ncs_conf_tool -e false ncs-config netconf enabled | \
		ncs_conf_tool -e false ncs-config webui enabled | \
		ncs_conf_tool -e false ncs-config restconf enabled > ncs.conf.tmp
	mv ncs.conf.tmp ncs.conf

packages:
	cp -R   ../../packages/edge \
			../../packages/origin \
			../../packages/skylight \
			../../packages/subscriber \
			packages/

clean:
	rm -rf packages ncs-cdb logs lux_logs netsim state scripts README.*
	rm -f *.log confderr.* global.data rr sess _tmp* ncs.conf *.beam

make reallyclean: clean
	make -C $(TEST_PACKAGE_STORE) clean

start:
	ncs-netsim -a start
	#ncs

stop:
	ncs-netsim -a stop 2>/dev/null || true
	#ncs --stop

cli:
	ncs_cli -u admin

netsim:
	make -C $(TEST_PACKAGE_STORE) build-packages
	rm -rf $@
	ncs-netsim --dir $@ \
		create-network $(TEST_PACKAGE_STORE)/packages/edge       1 edge \
		create-network $(TEST_PACKAGE_STORE)/packages/origin     1 origin \
		create-network $(TEST_PACKAGE_STORE)/packages/skylight   1 skylight \
		create-network $(TEST_PACKAGE_STORE)/packages/subscriber 1 subscriber
.PHONY: netsim
