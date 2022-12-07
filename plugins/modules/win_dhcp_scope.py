#!/usr/bin/python
# -*- coding: utf-8 -*-

# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_dhcp_scope
short_description: Manage Windows Server DHCP Scope
author: Benoit Ferré (@ferrebenoit)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Manage Windows Server DHCP Leases (IPv4 Only)
  - Adds, Removes and Modifies DHCP Scope
  - Task should be delegated to a Windows DHCP Server or Windows Workstation alongside computer_name option
options:
  type:
    description:
    type: str
    default: Dhcp
    choices: [ Dhcp, Bootp, Both ]
  state:
    description:
      - Specifies the desired state of the DHCP scope.
    type: str
    default: present
    choices: [ present, absent ]
  start_range:
    description:
    type: str
    required: no
  end_range:
    description:
    type: str
    required: no
  subnet_mask:
    description:
    type: str
    required: no
  scope_id:
    description:
    type: str
    required: yes
  name:
    description:
    type: str
  description:
    description:
      - Specifies the description for reservation being created.
      - Only applicable to l(type=reservation).
    type: str
  scope_state:
    description:
    type: str
    default: Active
    choices: [ Active, InActive]
  lease_duration:
    description:
    type: str
    default: 08.00:00:00
  computer_name:
    description:
      - Specifies a DHCP server.
      - You can specify an IP address or any value that resolves to an IP
        address, such as a fully qualified domain name (FQDN), host name, or
        NETBIOS name.
    type: str
'''

EXAMPLES = r'''
- name: Ensure DHCP scope exists delegate to workstation
  community.windows.win_dhcp_scope:
    computer_name: dhcpserver.contoso.com
    start_range: 10.20.20.1
    end_range: 10.20.20.254
    subnet_mask: 255.255.255.0
    name: Lab-5 Network
    scope_id: 10.20.20.0
  delegate_to: workstation.contoso.com

- name: Ensure DHCP scope doest not exists 
  community.windows.win_dhcp_scope:
    scope_id: 10.20.20.0
    state: absent
'''

RETURN = r'''
changed:
  description: True if the scope has changed
  returned: always
  type: boolean
  
scope:
  description: New/Updated DHCP object parameters
  returned: always
  type: dict
  sample:
    end_range: 10.20.20.254
    lease_duration: 08.00:00:00
    name: Lab-5 Network
    scope_id: 10.20.20.0
    scope_state: Active
    start_range: 10.20.20.1
    subnet_mask: 255.255.255.0
    type: Dhcp
'''
