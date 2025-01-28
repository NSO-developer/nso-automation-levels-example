"""NSO Automation Levels Example
(C) 2024 Cisco Systems
Permission to use this code as a starting point hereby granted

This module implements an NSO action callback that is used to optimize the running services.
When this action is invoked, it will start a background thread that reads the list of edge services
and re-deploys them one by one at regular intervals (see INTERVAL_TIME below). Invoking the same
action again will make the thread terminate.

See the top level README file for more information
"""
import ncs
from ncs.maapi import single_write_trans
from ncs.dp import Action
import time, traceback, threading

class StreamerOptimizeAction(ncs.dp.Action):
    INTERVAL_TIME = 15          # Number of seconds in between updates
    optimizer_thread = None     # Currently running thread that is optimizing services
    stop_requested = False      # Signals request to stop optimizing

    # actions optimize
    # Toggles automatic optimization (=re-deploy) of edge services.
    # cb_action is called by NSO when the action is invoked. This starts a background
    # thread that keeps redeploying edge service instances at regular intervals.
    # If the thread is already running, it will instead be requested to stop.
    @Action.action
    def cb_action(self, uinfo, name, kp, input, output, trans):
        try:
            if StreamerOptimizeAction.optimizer_thread:
                StreamerOptimizeAction.stop_requested = True
                output.result = "Stopped Optimizer"
                self.log.info(output.result)
            else:
                thread = threading.Thread(target=StreamerOptimizeAction.worker_thread, args=(self,), daemon=True)
                StreamerOptimizeAction.optimizer_thread = thread
                StreamerOptimizeAction.optimizer_thread.start()
                StreamerOptimizeAction.stop_requested = False
                output.result = "Started Optimizer"
                self.log.info(output.result)
        except:
            output.result = "Failed to start Optimizer"
            self.log.info(output.result)

    # worker_thread
    # Reactively re-deploys edge service instances, one at a time.
    # The thread runs every few seconds (INTERVAL_TIME) until requested to stop.
    def worker_thread(self):
        try:
            self.log.info(f'Optimizer thread running')
            edge_names = []
            while True:
                for wait in range(StreamerOptimizeAction.INTERVAL_TIME):
                    if StreamerOptimizeAction.stop_requested:
                        StreamerOptimizeAction.optimizer_thread = None
                        StreamerOptimizeAction.stop_requested = False
                        self.log.info(f'Optimizer thread terminating')
                        return True
                    time.sleep(1)
                with single_write_trans('admin', 'system', db=ncs.OPERATIONAL) as t:
                    r = ncs.maagic.get_root(t)
                    if not edge_names:
                        edge_names = r.streaming__edge.keys()
                    if not edge_names:
                        self.log.info(f'Optimizer found no services to optimize')
                        continue
                    edge = r.streaming__edge[edge_names.pop(0)]
                    self.log.info(f'Optimizer re-deploying service {edge.name}')
                    edge.reactive_re_deploy()

        except Exception as e:
            self.log.error('ERROR: ', e)
            self.log.error(traceback.format_exc())
            return False
