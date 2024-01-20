"""NSO Nano service example.

Implements a Nano service callback
(C) 2023 Cisco Systems
Permission to use this code as a starting point hereby granted

See the README file for more information
"""
import ncs
from ncs.maapi import single_write_trans
from ncs.dp import Action
import traceback

class SkylightNotificationAction(ncs.dp.Action):
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
            return True

        except Exception as e:
            self.log.error('ERROR: ', e)
            self.log.error(traceback.format_exc())
            return False
