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
import uuid, math
from streaming.skylight_notification_action import SkylightNotificationAction
from streaming.keep_optimizing_action import StreamerOptimizeAction
from streaming.vary_energy_price_action import StreamerVaryEnergyPriceAction

class ConnectedToSkylight(NanoService):
    @NanoService.create
    def cb_nano_create(self, tctx, root, service, plan, component, state, proplist, compproplist):
        self.log.info(f'cb_nano_create: ConnectedToSkylight for {service.name}')
        vars = ncs.template.Variables()

        # Create a unique session ID from the service name
        vars.add('SESSION_ID', str(uuid.uuid5(uuid.NAMESPACE_DNS,
                 f'{service.name}-edge-connected-to-skylight')))

        # Find the DC with the lowest jitter
        best_dc = None
        self.log.info(f'Selection of DC with the lowest jitter not yet implemented')
        if best_dc is None:
            raise Exception('No DC found')
        
        vars.add('DC', best_dc)                         # Value goes into the template applied now
        service.oper_status.chosen_dc = best_dc.name    # Value goes into operational data, usable
                                                        # by templates applied at later stages
        # Apply the template
        template = ncs.template.Template(service)
        template.apply('edge-servicepoint-edge-connected-to-skylight', vars)

# ---------------------------------------------
# COMPONENT THREAD THAT WILL BE STARTED BY NCS.
# ---------------------------------------------
class Main(ncs.application.Application):
    '''Nano service appliction implementing the nano create callback'''

    def setup(self):
        # The application class sets up logging for us. It is accessible
        # through 'self.log' and is a ncs.log.Log instance.
        self.log.info('Main RUNNING')

        self.register_nano_service(servicepoint='edge-servicepoint',
                                   componenttype="streaming:edge",
                                   state="streaming:connected-to-skylight",
                                   nano_service_cls=ConnectedToSkylight)
        # Nano service callbacks require a registration for a service point,
        # component, and state, as specified in the corresponding data model
        # and plan outline.

        # We would also like to register a few action callbacks
        self.register_action('skylight-notification', SkylightNotificationAction)
        self.register_action('optimize', StreamerOptimizeAction)
        self.register_action('vary-energy-price', StreamerVaryEnergyPriceAction)

        # When this setup method is finished, all registrations are
        # considered done and the application is 'started'.

    def teardown(self):
        # When the application is finished (which would happen if NCS went
        # down, packages were reloaded or some error occurred) this teardown
        # method will be called.

        self.log.info('Main FINISHED')
