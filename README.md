# Reaching Network Automation Level 5: Principles and Practice

[![Run in Cisco Cloud IDE](https://static.production.devnetcloud.com/codeexchange/assets/images/devnet-runable-icon.svg)](https://developer.cisco.com/devenv/?id=devenv-base-vscode-nso-local&GITHUB_SOURCE_REPO=https://github.com/NSO-developer/nso-automation-levels-example)

## Introduction

Once the Adaptive Service Activation Scripts (Network Automation
Level 2) are left behind, a world of life-cycle flexibility and
stylistic freedom of the services running in our network. What can we
use this flexibility for?

In this lab, the participant will upgrade a pre-existing Network
Services Orchestrator (NSO) service from Network Automation Level 3 to
Level 5 by adding service health measurement and make it adapt to
changes in the environment.

The vision of the Internet Engineering Task Force (IETF) Application
Level Traffic Optimization (ALTO) Working Group (WG) is to optimize the
application and network together, so that the delivered service is
delivered as well as possible to the collection of users. This might
mean delivering this user's service from a data center that is not the
closest one, but from another with less load or lower energy prices, and
therefore less expensive to the customer. Moving service instances
around becomes a natural part of the life-cycle.

Prerequisites:
* Basic programming skills in Python
* Some familiarity with NSO services and YANG modules

Key takeaways:
* Hands-on experience with Network Automation Levels 3-5
* Giddy feeling of power arising from services that adapt to their
  environment


## DISCLAIMER
This training document is to familiarize with Network Services
Orchestrator (NSO) and Network Automation Levels. Although the lab
design and configuration examples could be used as a reference, it’s not
a real design, thus not all recommended features are used, or enabled
optimally. For the design related questions please contact your
representative at Cisco, or a Cisco partner.


## THE SCENARIO

### Background

As an industry, we have been talking for years about "network
automation". The exact meaning of that concept has often been rather
nebulous. Attempts at defining more specific levels, similarly to how
the auto industry defined specified levels of "self driving cars".

Even with the examples showing what the network automation levels mean,
however, people did not get very clear and intuitive understanding of
what the levels mean.

The purpose of this lab is to give the participants a concrete,
hands-on, intuitive feel for the meaning of level 3, level 4 and level 5
network automation.

In this lab we going on a journey, starting at a pre-existing NSO level
3 service. The first stage of the journey will be to upgrade it to a
level 4 implementation by adding service monitoring functionality into
the service definition. The second stage takes the service to level 5 by
adding a mechanism for constant, on-going optimization of all service
instances.

You can read more about the network automation levels in this blog post

    https://community.cisco.com/t5/nso-developer-hub-blogs/network-automation-levels/ba-p/4742665


### Video Delivery Service

In this example, we are looking at a video delivery service. The service
is implemented by a network of data centers (DCs) and edge devices. Each
DC contains an Origin Video Server (this is something we made up for
this lab), and a generic firewall. The edge devices are Edge Video
Caches (again, this is something we made up for this lab), that are
built to work together with the Origin Video Servers. Imagined end-users
can then consume their video feeds through the Edge Video Caches.


    +-------------+                         +-------------+
    |             |       +----------+      |             |
    |   dc0       |       | skylight |      |   dc1       |
    |             |       +----------+      |             |
    | +---------+ |                         | +---------+ |
    | | origin0 | |                         | | origin1 | |
    | +----v----+ |                         | +----v----+ |
    |      |      |                         |      |      |
    |   +--v--+   |                         |   +--v--+   |
    |   | fw0 |   |                         |   | fw1 |   |
    |   +--v--+   |                         |   +--v--+   |
    +------|------+                         +-----/|\-----+
          /              +-----------------------+ | \
         /              /             +------------+  \
    +---v---+      +---v---+      +---v---+       +---v---+
    | edge0 |      | edge1 |      | edge2 |       | edge3 |
    +-------+      +-------+      +-------+       +-------+

    Fig 1. The network topology.

The NSO service we are talking about here controls how the Edge Video
Caches are connected to the DCs. Each Edge Video Cache must be connected
to exactly one DC, but which one can vary over time, depending on the DC
availability, delivered quality, load and the current energy price at
the DC location.

At the starting point of this lab, it is the NSO operators that manually
decide through configuration which DCs are considered available and
which Edge Video Caches are connected to which DCs. While the service at
this level automates the device configuration work for the Origin Video
Servers and firewalls, the manual decisions/configurations about DC
availability and which Edge device should connect to which DC obviously
is not automated to a high level. We call this level 3.


### Lab Starting-point

In the lab setup, we have a single NSO instance that controls all the
DCs, all the relevant devices in them, and all the Edge devices. All the
devices in the DC and the Edge devices are really NSO NETSIM devices.
That means they basically only implement the management interfaces as
described by their YANG models, but otherwise don’t really do anything.
We have endowed some of these NETSIMs with a little bit of additional
behavior, though, so that they react and respond to a few things. Such
functionality will be described later, as needed.

Also, logically part of each DC is an Accedian Skylight monitoring
system. In our setup, there is really only one instance of a skylight
system, or “device” as NSO tends to think of all managed systems as
devices. A single skylight is enough since we think of it as running “in
the cloud” outside our DCs.

When we start, the NSO system is already up and running with the level 3
service implementation, and there are Network Element Drivers (NEDs) for
all device types installed, and the devices are already listed in the
NSO device list.
