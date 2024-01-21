"""NSO Automation Levels Example
(C) 2024 Cisco Systems
Permission to use this code as a starting point hereby granted

This module implements an NSO action callback that is used to simulate varying energy prices.
When this action is invoked, it will start a background thread that changes the leaf
/streaming:dc/oper-status/energy-price
in each datacenter (DC) at regular intervals (see INTERVAL_TIME below). Invoking the same
action again will make the thread terminate.

See the top level README file for more information
"""
import ncs
from ncs.maapi import single_write_trans
from ncs.dp import Action
import time, traceback, threading, random

class StreamerVaryEnergyPriceAction(ncs.dp.Action):
    INTERVAL_TIME = 15          # Number of seconds in between updates
    energy_price_thread = None  # Currently running thread that is varying prices
    stop_requested = False      # Signals request to stop varying prices

    # actions vary-energy-price
    # Toggles automatic variation of the operational energy-price leaf in the DC list.
    # cb_action is called by NSO when the action is invoked. This starts a background
    # thread that keeps setting the energy price. If the thread is already running, 
    # it will instead be requested to stop.
    @Action.action
    def cb_action(self, uinfo, name, kp, input, output, trans):
        try:
            with single_write_trans('admin', 'system', db=ncs.OPERATIONAL) as t:
                r = ncs.maagic.get_root(t)
                curr_price = r.streaming__dc[r.streaming__dc.keys()[0]].oper_status.energy_price
                # If the above gives an exception, there probably isn't any energy-price leaf to vary
                # Tell the user immediately, since the worker thread has no good way of communicating
                # with the user
            if StreamerVaryEnergyPriceAction.energy_price_thread:
                StreamerVaryEnergyPriceAction.stop_requested = True
                output.result = "Stopped Varying Energy Price"
                self.log.info(output.result)
            else:
                thread = threading.Thread(target=StreamerVaryEnergyPriceAction.worker_thread, 
                                          args=(self,), daemon=True)
                StreamerVaryEnergyPriceAction.energy_price_thread = thread
                StreamerVaryEnergyPriceAction.energy_price_thread.start()
                StreamerVaryEnergyPriceAction.stop_requested = False
                output.result = "Started Varying Energy Price"
                self.log.info(output.result)
        except:
            output.result = "Failed to start Vary Energy Price"
            self.log.info(output.result)

    # worker_thread
    # Sets the operational DC energy-price leaf values. A random target price value and random
    # number of steps is assigned for each DC. In each iteration, the current price moves one
    # step closer to the target price value. When the target price is reached, the target is
    # deleted from the target dictionary, and a new target and number of steps will be assigned
    # in the next iteration. The thread runs every few seconds (INTERVAL_TIME) until requested 
    # to stop.
    def worker_thread(self):
        try:
            self.log.info(f'Vary Energy Price thread running')
            price_targets = {}
            dc_names = []
            while True:
                # Sleep for a while, and keep checking for request to stop
                for wait in range(StreamerVaryEnergyPriceAction.INTERVAL_TIME):
                    if StreamerVaryEnergyPriceAction.stop_requested:
                        StreamerVaryEnergyPriceAction.energy_price_thread = None
                        StreamerVaryEnergyPriceAction.stop_requested = False
                        self.log.info(f'Vary Energy Price thread terminating')
                        return True
                    time.sleep(1)
                # Start a transaction towards the operational data store
                with single_write_trans('admin', 'system', db=ncs.OPERATIONAL) as t:
                    r = ncs.maagic.get_root(t)
                    if not dc_names:
                        # List of DCs empty? Reset to list of all DCs
                        dc_names = r.streaming__dc.keys()
                    # Take the first DC in the list, and remove it from the work item list
                    dc = r.streaming__dc[dc_names.pop(0)]
                    if dc.name not in price_targets:
                        price_targets[dc.name] = { 
                            'steps': random.choice([1,3,4,5,8]), 
                            'value': max(0,int(random.normalvariate(mu=100, sigma=40))) 
                        }
                    curr_price = int(dc.oper_status.energy_price) or 100
                    curr_steps = price_targets[dc.name].get('steps',1)
                    curr_target = price_targets[dc.name].get('value',100)
                    if curr_steps <= 1:
                        # Last step for this price target, set directly and delete the target
                        new_price = curr_target
                        del price_targets[dc.name]
                    else:
                        # Take one step towards price target, decrease number of remaining steps
                        new_price = int(curr_price + (curr_target - curr_price)/curr_steps)
                        price_targets[dc.name]['steps'] -= 1
                    dc.oper_status.energy_price = new_price
                    t.apply()
                    self.log.info(f'Vary Energy Price set DC {dc.name} energy price to {new_price}')

        except Exception as e:
            self.log.error('ERROR: ', e)
            self.log.error(traceback.format_exc())
            return False
