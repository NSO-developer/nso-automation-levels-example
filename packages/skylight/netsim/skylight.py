"""
*********************************************************************
* Skylight Netsim example                                           *
* Implements a couple of actions                                    *
*                                                                   *
* (C) 2023 Cisco Systems                                            *
* Permission to use this code as a starting point hereby granted    *
*********************************************************************
"""

import logging
import os
import sys
import time


import ncs
from ncs.dp import Action, Daemon
from ncs.maapi import Maapi
from ncs.log import Log



#logger class used by Daemon
class MyLog(object):
    def info(self, arg):
        print("info: %s" % arg)
    def error(self, arg):
        print("error: %s" % arg)


class SendNotificationAction(Action):
    @Action.action
    def cb_action(self, uinfo, name, kp, input, output):
        self.log.info("Notification sent")


def load_schemas():
    with Maapi():
        pass


if __name__ == "__main__":
    logger = logging.getLogger('skylight-netsim')
    logging.basicConfig(filename='skylight-netsim.log',
              format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
              level=logging.DEBUG)

    load_schemas()
    log = Log(logger, add_timestamp=True)
    d = Daemon(name='skylight-netsim', log=log)

    a = []
    a.append(SendNotificationAction(daemon=d,
                       actionpoint='skylight-send-notification', log=log))

    log.info('--- Daemon Skylight Netsim STARTED ---')
    try:
        d.start()

        while True:
            d.join(1)
            if not d.is_alive():
                break
    except Exception as e:
        print("ERROR:", e)


    #if not d.isAlive():
    #    d.finish()
    #    d.join()

    log.info('--- Daemon myaction FINISHED ---')
