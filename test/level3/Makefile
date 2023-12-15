# Mandatory targets
TEST_PACKAGE_STORE=../../

build: netsim ncs ncs-packages

ncs:
	ncs-setup --dest . --netsim-dir ./netsim
	sed 's|>\./|>$(PWD)/|g' ncs.conf | \
		ncs_conf_tool -e false ncs-config netconf enabled | \
		ncs_conf_tool -e false ncs-config webui enabled | \
		ncs_conf_tool -e false ncs-config restconf enabled | \
		ncs_conf_tool -e false ncs-config rest enabled > ncs.conf.tmp
	mv ncs.conf.tmp ncs.conf

ncs-packages:
	cp -R ../../packages/streaming-level3 packages/streaming
	make -C packages/streaming/src all

clean:
	make -C $(TEST_PACKAGE_STORE) clean
	rm -rf packages ncs-cdb logs lux_logs netsim state scripts README.ncs README.netsim
	rm -f *.log confderr.* global.data rr sess _tmp* ncs.conf *.beam

start:
	ncs-netsim -a start
	ncs

stop:
	ncs-netsim -a stop 2>/dev/null || true
	ncs --stop

cli:
	ncs_cli -u admin

netsim:
	make -C $(TEST_PACKAGE_STORE) build-packages
	rm -rf $@
	ncs-netsim --dir $@ \
		create-network $(TEST_PACKAGE_STORE)/packages/edge       4 edge \
		create-network $(TEST_PACKAGE_STORE)/packages/origin     2 fw \
		create-network $(TEST_PACKAGE_STORE)/packages/skylight   2 skylight \
		create-network $(TEST_PACKAGE_STORE)/packages/origin     2 mediaorigin \
		create-network $(TEST_PACKAGE_STORE)/packages/subscriber 2 subscriber
.PHONY: netsim

