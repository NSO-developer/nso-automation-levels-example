"""
*********************************************************************
* Skylight Netsim example                                           *
* Implements a couple of actions                                    *
*                                                                   *
* (C) 2023 Cisco Systems                                            *
* Permission to use this code as a starting point hereby granted    *
*********************************************************************
"""

from datetime import datetime
import logging
import os
import random
import socket
import sys
import time

import _ncs
import ncs
from ncs.dp import Action, Daemon
from ncs.maapi import Maapi
from ncs.log import Log

from skylight_netsim_ns import ns

xmltag = _ncs.XmlTag
value = _ncs.Value
tagvalue = _ncs.TagValue


def get_date_time():
    now = datetime.now()
    confdNow = _ncs.DateTime(
        year=now.year,
        month=now.month,
        day=now.day,
        hour=now.hour,
        min=now.minute,
        sec=now.second,
        micro=now.microsecond,
        timezone=0,
        timezone_minutes=0)
    return confdNow


notif_daemon = None


class NotificationDaemon:
    def __init__(self, name, stream):
        self.ndaemon = ncs.dp.Daemon(name)
        self.nsock = socket.socket()
        _ncs.dp.connect(self.ndaemon.ctx(), self.nsock,
                            _ncs.dp.WORKER_SOCKET, "127.0.0.1", ncs.PORT)
        self.nctx = _ncs.dp.register_notification_stream(self.ndaemon.ctx(),
                                      None, self.nsock, stream)
    def start(self):
        self.ndaemon.start()
    def finish(self):
        self.ndaemon.finish()
    def join(self):
        self.ndaemon.join()

    def send(self, device, jitter):
        values = [
            tagvalue(xmltag(ns.hash,
                            ns.skylight_netsim_skylight_event),
                     value((ns.skylight_netsim_skylight_event, ns.hash),
                           _ncs.C_XMLBEGIN)
                     ),
            tagvalue(xmltag(ns.hash,
                            ns.skylight_netsim_device),
                     value(device, _ncs.C_BUF)),

            tagvalue(xmltag(ns.hash,
                            ns.skylight_netsim_jitter),
                     value((jitter, 3), _ncs.C_DECIMAL64)),

            tagvalue(xmltag(ns.hash,
                            ns.skylight_netsim_skylight_event),
                     value((ns.skylight_netsim_skylight_event, ns.hash),
                           _ncs.C_XMLEND)
                     )
        ]
        _ncs.dp.notification_send(self.nctx, get_date_time(), values)


class SendNotificationAction(Action):
    @Action.rpc
    def cb_action(self, uinfo, name, input, output):
        if input.jitter:
            jitter = int(float(input.jitter)*1000)
        elif name == "send-notification-high-jitter":
            jitter = random.randint(5000, 8000)
        else:
            jitter = random.randint(1000, 3000)

        if notif_daemon is not None:
            notif_daemon.send(input.device, jitter)
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

    daemons = []

    d = Daemon(name='skylight-netsim', log=log)
    daemons.append(d)

    a = []
    a.append(SendNotificationAction(daemon=d,
                       actionpoint='skylight-send-notification', log=log))

    notif_daemon = NotificationDaemon("skylight-notification-daemon",
                                        "notification-stream")
    daemons.append(notif_daemon)

    log.info('--- Daemon Skylight Netsim STARTED ---')

    try:
        for daemon in daemons:
            daemon.start()

        while True:
            d.join(1)
            if not d.is_alive():
                daemons.remove(d)
                break
    except Exception as e:
        print("ERROR:", e)


    for daemon in daemons:
        daemon.finish()
        daemon.join()


    log.info('--- Daemon myaction FINISHED ---')
