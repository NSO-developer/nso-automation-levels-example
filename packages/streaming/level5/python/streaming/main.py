"""NSO Nano service example.

Implements a Nano service callback
(C) 2023 Cisco Systems
Permission to use this code as a starting point hereby granted

See the README file for more information
"""
import ncs
from ncs.application import NanoService
import uuid, math
from streaming.skylight_notification_action import SkylightNotificationAction
from streaming.keep_optimizing_action import StreamerOptimizeAction
from streaming.vary_energy_price_action import StreamerVaryEnergyPriceAction

class ConnectedToSkylight(NanoService):
    JITTER_WEIGHT = 1
    PRICE_WEIGHT = 2

    @NanoService.create
    def cb_nano_create(self, tctx, root, service, plan, component, state, proplist, compproplist):
        self.log.info(f'cb_nano_create: ConnectedToSkylight for {service.name}')
        vars = ncs.template.Variables()
        # Create a unique session ID from the service name
        vars.add('SESSION_ID', str(uuid.uuid5(uuid.NAMESPACE_DNS,
                 f'{service.name}-edge-connected-to-skylight')))

        # Find the DC with the lowest score
        best_score = 100000
        best_dc = None
        for n in root.dc:
            if n.oper_status.jitter is None or n.oper_status.energy_price is None:
                self.log.info(f'Checking DC {n.name}: DC is not ready')
                continue # Data not available yet, disregard this option
            if len(n.oper_status.edge_clients) >= n.edge_capacity and service.name not in n.oper_status.edge_clients:
                self.log.info(f'Checking DC {n.name}: DC is full')
                continue # Already full, not an option
            dc_jitter = float(n.oper_status.jitter)
            dc_price = int(n.oper_status.energy_price)
            dc_score = ConnectedToSkylight.JITTER_WEIGHT * math.log10(dc_jitter) + \
                       ConnectedToSkylight.PRICE_WEIGHT * math.log10(dc_price)
            self.log.info(f'Checking DC {n.name}: jitter {dc_jitter} price {dc_price} -> score {dc_score}')
            if dc_score < best_score:
                best_score = dc_score
                best_dc = n
        if best_dc is None:
            raise Exception('No DC found')
        vars.add('DC', best_dc)
        if service.oper_status.chosen_dc:
            self.log.info(f'Leaving DC {root.dc[service.oper_status.chosen_dc].name}')
            root.dc[service.oper_status.chosen_dc].oper_status.edge_clients.remove(service.name)
        service.oper_status.chosen_dc = best_dc.name
        self.log.info(f'Using DC {root.dc[service.oper_status.chosen_dc].name}')
        root.dc[service.oper_status.chosen_dc].oper_status.edge_clients.create(service.name)

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

        # If we registered any callback(s) above, the Application class
        # took care of creating a daemon (related to the service/action point).
        self.register_action('skylight-notification',
                             SkylightNotificationAction)

        self.register_action('optimize',
                             StreamerOptimizeAction)

        self.register_action('vary-energy-price',
                             StreamerVaryEnergyPriceAction)

        # When this setup method is finished, all registrations are
        # considered done and the application is 'started'.

    def teardown(self):
        # When the application is finished (which would happen if NCS went
        # down, packages were reloaded or some error occurred) this teardown
        # method will be called.

        self.log.info('Main FINISHED')
