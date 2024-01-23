"""NSO Automation Levels Example
(C) 2024 Cisco Systems
Permission to use this code as a starting point hereby granted

This module implements an NSO service creation callback for the connected-to-skylight state.
At this point in the service creation, the important question is which datacenter (DC) this
edge service instance should connect to.

There are several factors to consider:
- How much jitter is measured for each DC
- What is the energy price at each DC
- Is there still capacity for more edge services at each DC

This module provides a selection function that takes the above into consideration. It also
registers this nano-service creation callback with NSO, as well as a few action callbacks
that are imported.

See the top level README file for more information
"""
import ncs
from ncs.application import NanoService
from ncs.dp import Action
import uuid, math
from streaming.skylight_notification_action import SkylightNotificationAction
from streaming.keep_optimizing_action import StreamerOptimizeAction
from streaming.vary_energy_price_action import StreamerVaryEnergyPriceAction

class DCInit(NanoService):
    @NanoService.create
    def cb_nano_create(self, tctx, root, service, plan, component, state, proplist, compproplist):
        self.log.info(f'cb_nano_create: DCInit for {service.name}')

        # Find the DC with the lowest jitter
        best_jitter = 100000
        best_dc = None
        for dc in root.dc:
            if dc.oper_status.jitter is None:
                self.log.info(f'Checking DC {dc.name}: DC is not ready')
                continue # Data not available yet, disregard this option
            dc_jitter = float(dc.oper_status.jitter)
            self.log.info(f'Checking DC {dc.name}: jitter {dc_jitter}')
            if dc_jitter < best_jitter:
                best_jitter = dc_jitter
                best_dc = dc
        if best_dc is None:
            raise Exception('No DC found')
        self.log.info(f'Found DC {best_dc} with the lowest jitter {best_jitter}')
        
        service.oper_status.chosen_dc = best_dc.name    # Value goes into operational data, usable
                                                        # by templates applied at later stages

class ConnectedToSkylight(NanoService):
    @NanoService.create
    def cb_nano_create(self, tctx, root, service, plan, component, state, proplist, compproplist):
        self.log.info(f'cb_nano_create: ConnectedToSkylight for {service.name}')
        vars = ncs.template.Variables()

        # Create a unique session ID from the service name
        vars.add('SESSION_ID', str(uuid.uuid5(uuid.NAMESPACE_DNS,
                 f'{service.name}-edge-connected-to-skylight')))
        # Apply the template
        template = ncs.template.Template(service)
        template.apply('edge-servicepoint-edge-connected-to-skylight', vars)

class LoadFromStoragePostAction(ncs.dp.Action):
    # This action is meant to be invoked by the nano service as a post-action.
    # The action instructs the origin server to load content from storage.
    @Action.action
    def cb_action(self, uinfo, name, kp, input, output, trans):
        self.log.info(f'LoadFromStoragePostAction: for {kp}')
        root = ncs.maagic.get_root(trans)
        service = root._get_node(kp)
        origin_name = root.dc[service.oper_status.chosen_dc].media_origin
        self.log.info(f'Invoking load-from-storage rpc on {origin_name}')
        root.devices.device[origin_name].rpc.rpc_load_from_storage.load_from_storage()
        self.log.info(f'The load-from-storage rpc on {origin_name} is completed')
        output.result = True

# ---------------------------------------------
# COMPONENT THREAD THAT WILL BE STARTED BY NCS.
# ---------------------------------------------
class Main(ncs.application.Application):
    '''Nano service appliction implementing the nano create callback'''

    def setup(self):
        # The application class sets up logging for us. It is accessible
        # through 'self.log' and is a ncs.log.Log instance.
        self.log.info('Main RUNNING')

        # Nano service callbacks require a registration for a service point,
        # component, and state, as specified in the corresponding data model
        # and plan outline.
        self.register_nano_service(servicepoint='edge-servicepoint',
                                   componenttype="streaming:dc",
                                   state="ncs:init",
                                   nano_service_cls=DCInit)

        self.register_nano_service(servicepoint='edge-servicepoint',
                                   componenttype="streaming:edge",
                                   state="streaming:connected-to-skylight",
                                   nano_service_cls=ConnectedToSkylight)

        # We would also like to register a few action callbacks
        self.register_action('skylight-notification', SkylightNotificationAction)
        self.register_action('optimize', StreamerOptimizeAction)
        self.register_action('vary-energy-price', StreamerVaryEnergyPriceAction)
        self.register_action('load-from-storage', LoadFromStoragePostAction)

        # When this setup method is finished, all registrations are
        # considered done and the application is 'started'.

    def teardown(self):
        # When the application is finished (which would happen if NCS went
        # down, packages were reloaded or some error occurred) this teardown
        # method will be called.

        self.log.info('Main FINISHED')
