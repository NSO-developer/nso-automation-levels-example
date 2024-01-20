"""NSO Nano service example.

Implements a Nano service callback
(C) 2023 Cisco Systems
Permission to use this code as a starting point hereby granted

See the README file for more information
"""
import ncs
from ncs.maapi import single_write_trans
from ncs.dp import Action
import time, traceback, threading

class StreamerOptimizeAction(ncs.dp.Action):
    optimizer_thread = None
    stop_requested = False

    @Action.action
    def cb_action(self, uinfo, name, kp, input, output, trans):
        try:
            if StreamerOptimizeAction.optimizer_thread:
                StreamerOptimizeAction.stop_requested = True
                output.result = "Stopped Optimizer"
                self.log.info(output.result)
            else:
                StreamerOptimizeAction.energy_price_thread = threading.Thread(target=StreamerOptimizeAction.worker_thread, args=(self,), daemon=True)
                StreamerOptimizeAction.energy_price_thread.start()
                StreamerOptimizeAction.stop_requested = False
                output.result = "Started Optimizer"
                self.log.info(output.result)
        except:
            output.result = "Failed to start Optimizer"
            self.log.info(output.result)

    def worker_thread(self):
        try:
            self.log.info(f'Optimizer thread running')
            targets = {}
            edges = []
            while True:
                for wait in range(15):
                    if StreamerOptimizeAction.stop_requested:
                        StreamerOptimizeAction.optimizer_thread = None
                        StreamerOptimizeAction.stop_requested = False
                        self.log.info(f'Optimizer thread terminating')
                        return True
                    time.sleep(1)
                with single_write_trans('admin', 'system', db=ncs.OPERATIONAL) as t:
                    r = ncs.maagic.get_root(t)
                    if not edges:
                        edges = r.streaming__edge.keys()
                    if not edges:
                        self.log.info(f'Optimizer found no services to optimize')
                        continue
                    edge = r.streaming__edge[edges.pop(0)]
                    self.log.info(f'Optimizer re-deploying service {edge.name}')
                    edge.reactive_re_deploy()
        except Exception as e:
            self.log.error('ERROR: ', e)
            self.log.error(traceback.format_exc())
            return False
