# NAME
zbxdynlacp.pl - Create dynamically Zabbix items and triggers for monitoring link aggregations.

zbxdynrrpp.pl - Create dynamically Zabbix items and triggers for monitoring RRPP rings.

# DESCRIPTION
These scripts will automatically create items and triggers on a Zabbix server to monitor link aggregation or RRPP rings. The hosts on which the scripts will be run need to be in specific Zabbix groups. 

The scripts will retrieve the link aggregations or the RRPP rings configured on the switch with SNMP requests.

# PREREQUISITE

The following modules are needed: 
* Zabbix::Tiny
* YAML::XS

# ARGUMENTS
    -h --help
        Display the help message

    -v --version
        Display the version message

    -p
        Path to the configuration file (by default /etc/zabbix/zbxdyn.conf)

    -c --create-interface
        Create SNMP interface if noexistent

    -s
        Display the statistics per host

    -d
        Display the debug messages

# CONFIGURATION FILE
The configuration file is written in YAML. It should contains the Zabbix username and password for using the API as well a the url for requesting the API. It should also provided the groups of hosts on which the script will be run.

Here are an example of a configuration file:
```
---
zabbix_username: Admin
zabbix_password: zabbix
zabbix_url: http://192.168.0.100/zabbix/api_jsonrpc.php
LACP_groups:
  - LACP_DYN
RRPP_groups:
  - RRPP_DYN
```

# USAGE

## Host Group
The zabbix hosts on which the script will be run need to be in a group which name is in the configuration file. 

For example, a LACP_DYN group can be created on the zabbix server and every host that need its aggregations to be monitored will be in this group.

If a host is remove from this group, the items and triggers automatically created by the script will be deleted.

## Macros
There are several macro that are needed for the script to run. It is not mandatory to define them as default values are defined: 
Global:
* {$SNMP_COMMUNITY}: the SNMP community of the switch ('public' by default)
* {$SNMP_TIMEOUT}: the timeout of the SNMP request in second (5 by default)
* {$SNMP_RETRIES}: the number of retries of the SNMP request (0 by default)

For LACP:
* {$LACP_ITEM_DELAY}: the delay of the items created (60 by default)
* {$PRIORITY_LACP_DOWN}: the priority of the trigger when the aggregation is down (5 by default)
* {$PRIORITY_LACP_PARTIALLY_DOWN}: the priority of the trigger when the aggregation is partially down (2 by default)

For RRPP:
* {$RRPP_ITEM_DELAY}: the delay of the items created (60 by default)
* {$PRIORITY_RRPP_OPEN}: the priority of the trigger when the ring is open (2 by default)

These macros can be defined globaly in Administration > General > Macro, or per template or host (in the Macros tab)

## Ping dependencie
If the host have a ping check configured (with the Zabbix icmpping function) it will be add as a dependencie for the created triggers. Otherwise no dependencie will be set.

## SNMP interface
If no SNMP interface is defined on the host you can create it from the agent interface using the option -c --create-interface.

# AUTHOR
Romain CYRILLE

# LICENSE

This file is part of zbxdynlacp.

Zbxdyn is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
any later version.

Zbxdyn is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Zbxdyn.  If not, see <http://www.gnu.org/licenses/>.

