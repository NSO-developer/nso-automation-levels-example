"""NSO Automation Levels Example
(C) 2024 Cisco Systems
Permission to use this code as a starting point hereby granted

This module implements an NSO action callback that is invoked whenever the skylight monitoring system
sends a notification about one of the monitored devices. This action will then set the jitter value
/streaming:dc/oper-status/jitter
for the datacenter (DC) mentioned in the notification.

See the top level README file for more information
"""
import ncs
from ncs.maapi import single_write_trans
from ncs.dp import Action
import traceback

class SkylightNotificationAction(ncs.dp.Action):
    # actions skylight-notification
    # This action is meant to be invoked by an NSO notification kicker, but operators could also invoke it,
    # if desired. It will set the DC jitter value to the value provided in the action parameters.
    @Action.action
    def cb_action(self, uinfo, name, kp, input, output, trans):
        try:
            root = ncs.maagic.get_root(trans)
            notification = root._get_node(input.path)
            self.log.info(f'Got notification type {notification} {notification.device} {notification.jitter}')
            with single_write_trans('admin', 'system', db=ncs.OPERATIONAL) as t:
                r = ncs.maagic.get_root(t)
                r.streaming__dc[notification.device].oper_status.jitter = notification.jitter
                t.apply()

                # Automatically re-deploy services that are on the DC in the notification,
                # but let all other services stay as they are
                for edge in r.streaming__edge:
                    if edge.oper_status.chosen_dc == notification.device:
                        self.log.info(f'Re-deploying service {edge.name}')
                        edge.reactive_re_deploy()
                    else:
                        self.log.info(f'Leaving service {edge.name} on {edge.oper_status.chosen_dc} as is')

            return True

        except Exception as e:
            self.log.error('ERROR: ', e)
            self.log.error(traceback.format_exc())
            return False
