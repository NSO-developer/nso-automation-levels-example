DIR = ..

include $(DIR)/Makefile

all: skylight_netsim_ns.py

skylight_netsim_ns.py: skylight-netsim.fxs
	$(NCSC) --emit-python $@ $<
