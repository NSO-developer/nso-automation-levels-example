"""NSO Nano service example.

Implements a Nano service callback
(C) 2023 Cisco Systems
Permission to use this code as a starting point hereby granted

See the README file for more information
"""
import ncs
from ncs.maapi import single_write_trans
from ncs.dp import Action
import time, traceback, threading, random

class StreamerVaryEnergyPriceAction(ncs.dp.Action):
    energy_price_thread = None
    stop_requested = False

    @Action.action
    def cb_action(self, uinfo, name, kp, input, output, trans):
        try:
            with single_write_trans('admin', 'system', db=ncs.OPERATIONAL) as t:
                r = ncs.maagic.get_root(t)
                curr_price = r.streaming__dc[r.streaming__dc.keys()[0]].oper_status.energy_price
                # If the above gives an exception, there probably isn't any energy-price leaf to vary
            if StreamerVaryEnergyPriceAction.energy_price_thread:
                StreamerVaryEnergyPriceAction.stop_requested = True
                output.result = "Stopped Varying Energy Price"
                self.log.info(output.result)
            else:
                StreamerVaryEnergyPriceAction.energy_price_thread = threading.Thread(target=StreamerVaryEnergyPriceAction.worker_thread, args=(self,), daemon=True)
                StreamerVaryEnergyPriceAction.energy_price_thread.start()
                StreamerVaryEnergyPriceAction.stop_requested = False
                output.result = "Started Varying Energy Price"
                self.log.info(output.result)
        except:
            output.result = "Failed to start Vary Energy Price"
            self.log.info(output.result)

    def worker_thread(self):
        try:
            self.log.info(f'Vary Energy Price thread running')
            targets = {}
            dcs = []
            while True:
                for wait in range(15):
                    if StreamerVaryEnergyPriceAction.stop_requested:
                        StreamerVaryEnergyPriceAction.energy_price_thread = None
                        StreamerVaryEnergyPriceAction.stop_requested = False
                        self.log.info(f'Vary Energy Price thread terminating')
                        return True
                    time.sleep(1)
                with single_write_trans('admin', 'system', db=ncs.OPERATIONAL) as t:
                    r = ncs.maagic.get_root(t)
                    if not dcs:
                        dcs = r.streaming__dc.keys()
                    dc = r.streaming__dc[dcs.pop(0)]
                    if dc.name not in targets:
                        targets[dc.name] = { 'steps': random.choice([1,3,4,5,8]), 
                                             'value': max(0,int(random.normalvariate(mu=100, sigma=40))) }
                    curr_price = int(dc.oper_status.energy_price) or 100
                    curr_steps = targets[dc.name].get('steps',1)
                    curr_target = targets[dc.name].get('value',100)
                    if curr_steps <= 1:
                        new_price = curr_target
                        del targets[dc.name]
                    else:
                        new_price = int(curr_price + (curr_target - curr_price)/curr_steps)
                        targets[dc.name]['steps'] -= 1
                    dc.oper_status.energy_price = new_price
                    t.apply()
                    self.log.info(f'Vary Energy Price set DC {dc.name} energy price to {new_price}')

        except Exception as e:
            self.log.error('ERROR: ', e)
            self.log.error(traceback.format_exc())
            return False
