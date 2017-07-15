# NAME
zbxdynlacp.pl - Create dynamically Zabbix items and triggers for monitoring link aggregations

# DESCRIPTION
This script will automatically create items and triggers on a Zabbix server to monitor link aggregation. The hosts on which the script will be runned need to be in a specific Zabbix group. 

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
The configuration file is written in YAML. It should contains the Zabbix username and password for using the API as well a the url for requesting the API. It should also provided the groups of hosts on which the script will be runned.

Here are an example of a configuration file:
```
---
zabbix_username: Admin
zabbix_password: zabbix
zabbix_url: http://192.168.0.100/zabbix/api_jsonrpc.php
LACP_groups:
  - LACP_DYN
```

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
