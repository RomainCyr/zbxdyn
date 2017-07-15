# NAME
zbxdynlacp.pl - Create dynamically Zabbix items and triggers for monitoring link aggregations

# DESCRIPTION
This script will automatically create items and triggers on a Zabbix server to monitor link aggregation. The hosts on which the script will be run need to be in a specific Zabbix group. 

The script will retrieve the link aggregation configured on the switch with SNMP requests.
    
# ARGUMENTS
    -h --help
        Display the help message

    -v --version
        Display the version message

    -c
        Path to the configuration file

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
```

# Usage
The zabbix hosts on which the script will be run need to be in a group which name is in the configuratino file. 

For example, a LACP_DYN group can be created on the zabbix server and every host that need to be monitored will be in this group.

There are several macro that are needed for this scrip to run. It is not mandatory to define them as default value are defined: 
* {$LACP_ITEM_DELAY}: the delay of the items created (60 by default)
* {$PRIORITY_LACP_DOWN}: the priority of the trigger when the aggregation is down (5 by default)
* {$PRIORITY_LACP_PARTIALLY_DOWN}: the priority of the trigger when the aggregation is partially down (2 by default)
* {$SNMP_COMMUNITY}: the SNMP community of the switch ('public' by default)
* {$SNMP_TIMEOUT}: the timeout of the SNMP request in second (5 by default)
* {$SNMP_RETRIES}: the number of retries of the SNMP request (0 by default)

These macros can be defined globaly in Administration > General > Macro, or per template or host (in the Macros tab)

# AUTHOR
Romain CYRILLE

# LICENSE
This file is part of zbxdynlacp.

Zbxdynlacp is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later
version.

Zbxdynlacp is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with Zbxdynlacp. If not, see <http://www.gnu.org/licenses/>.