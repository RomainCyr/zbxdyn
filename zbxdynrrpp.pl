#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use Zabbix::Tiny;
use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);
use YAML::XS qw(LoadFile);
use Utils::HPSNMP qw(HP_get_switch_rings);
use myZabbix::Operations qw(get_hosts_in_groups);
use vars qw($VERSION);
$VERSION = 0.1;

use Data::Dumper;

use constant{
	RRPP_ITEM_DELAY => 60,
	PRIORITY_RRPP_OPEN => 2,
	SNMP_COMMUNITY => 'public',
	SNMP_TIMEOUT =>5 ,
	SNMP_RETRIES => 0
};


# Handle command line arguments
my $configuration_file;
my $help;
my $create;
my $version;
my $debug;
my $statistics;

GetOptions(
	'help|h' => \$help,
	'version|v' => \$version,
	'p=s' => \$configuration_file,
	'create-interface|c' => \$create,
	's' => \$statistics,
	'd' => \$debug
)or die("Error in command line arguments\n");

if($version){
	print "$0 version $VERSION\n";
	exit 0;
}

if($help){
	print
	"Usage:\n\t$0 [-p <configuration_file>]\nOptions:
	-h --help \t\tShow this Screen		
	-v --version \tVersion of the scrip
	-p \t\tPath to the configuration file
	-c --create-interface\t\tCreate SNMP interface if noexistent
	-s \t\tShow statistics per host
	-d \t\tDebug mode\n";
	exit 0;
}

if(!$configuration_file){
	$configuration_file = '/etc/zabbix/zbxdyn.conf';
	print "INFO Using default path for configuration file: $configuration_file\n" if($debug);
}

#Load configuration file
my $config = LoadFile($configuration_file);
my $zabbix_username = $config->{zabbix_username};
my $zabbix_password = $config->{zabbix_password};
my $zabbix_url = $config->{zabbix_url};
my @RRPP_groups = $config->{RRPP_groups};

#Connect to Zabbix server to retrieve authentication token
print "INFO Connecting to Zabbix Server\n" if($debug);
my $zabbix = Zabbix::Tiny->new(
	server   => $zabbix_url,
	password => $zabbix_password,
	user     => $zabbix_username
);

#Construct list of Zabbix Host
print "INFO Retrieving Zabbix Hosts\n" if($debug);
my $hosts_ref = get_hosts_in_groups($zabbix,\@RRPP_groups);

for my $host (@$hosts_ref){

	print "INFO Retrieving Zabbix items for host $host->{name}\n" if($debug);
	$host->retrieve_items($zabbix);
	print "INFO Retrieving Zabbix triggers for host $host->{name}\n" if($debug);
	$host->retrieve_triggers($zabbix);
	print "INFO Retrieving Zabbix macros for host $host->{name}\n" if($debug);
	$host->retrieve_macros($zabbix);
	print "INFO Retrieving Zabbix snmp interfaces for host $host->{name}\n" if($debug);
	$host->retrieve_snmp_interface($zabbix,$create);

	my $snmp_community = $host->get_macro_by_name('{$SNMP_COMMUNITY}');
	if(!defined($snmp_community)){
		$snmp_community = SNMP_COMMUNITY;
		print "WARNING No SNMP community defined for host '$host->{name}' using default community '$snmp_community'\n" if($debug);
	}

	my $snmp_timeout = $host->get_macro_by_name('{$SNMP_TIMEOUT}');
	if(!defined($snmp_timeout)){
		$snmp_timeout = SNMP_TIMEOUT;
		print "WARNING No SNMP timeout defined for host '$host->{name}' using default of $snmp_timeout seconds\n" if($debug);
	}
	
	my $snmp_retries = $host->get_macro_by_name('{$SNMP_RETRIES}');
	if(!defined($snmp_retries)){
		$snmp_retries = SNMP_RETRIES;
		print "WARNING No SNMP retries defined for host '$host->{name}' using default of $snmp_retries retries\n" if($debug);
	}
	
	print "INFO Retrieving RRPP ring on switch '$host->{name}' with IP $host->{ip}\n" if($debug);
	my $rings;
	my $error;
	eval{
		$rings = HP_get_switch_rings(
			hostname => $host->ip,
			port => $host->snmp_port,
			community => $snmp_community,
			timeout => $snmp_timeout,
			retries => $snmp_retries
		);
	} or do{
		my $error = $@;
		print "ERROR Host '$host->{name}' with IP $host->{ip}: $error\n"; 
	};

	if($rings){
		my $up_to_date_items = 0;
		my $created_items = 0;
		my $updated_items = 0;
		my $deleted_items = 0;
		my $up_to_date_triggers = 0;
		my $created_triggers = 0;
		my $updated_triggers = 0;

		my $required_items = calculate_items_from_rings($host,$rings);
		# Compare host calculated items with current item and create, update item as required
		for my $required_item (@$required_items){
			my $item_exist = 0;
			for my $item (@{$host->items}){
				if ($required_item->equal($item)){
					$up_to_date_items += 1;
					$required_item->id($item->id);
					$item_exist = 1;
					last;
				}
				elsif($required_item ->name eq $item ->name){
					$updated_items += 1;
					$required_item->id($item->id);
					$item = $required_item;
					print "INFO Updating zabbix item '$required_item->{name}' on host $host->{name}\n" if($debug);
					$required_item->update($zabbix);
					$item_exist = 1;
					last;
				}
			}
			if (!$item_exist){
				$created_items +=1;
				print "INFO Creating zabbix item '$required_item->{name}' on host $host->{name}\n" if($debug);
				$required_item->create($zabbix);
			}
		}
		# Delete items not required
		for my $item (@{$host->items}){
			my $regex = qr/\[Auto RRPP\]/p;
			if ($item->name =~ /$regex/g){
				my $delete = 1;
				for my $required_item (@$required_items){
					if($item->equal($required_item)){
						$delete = 0;
						last;
					}
				}	
				if($delete){
					$deleted_items += 1;
					print "INFO Deleting zabbix item '$item->{name}' on host $host->{name}\n" if($debug);
					$item->delete($zabbix);
				}
			}
		}

		#Retrieve a ping check trigger for dependencie
		my $ping_trigger_id;
		for my $trigger (@{$host->triggers}){
			my $regex = qr/icmpping(\.|\[)/p;
			if($trigger->expression =~ /$regex/g){
				$ping_trigger_id = $trigger->id;
			}
		}
		if(!$ping_trigger_id && $debug){
			print "WARNING No ping check trigger defined on host $host->{name}, no ping dependencie will be set\n";
		}

		my $required_triggers = calculate_triggers_from_rings($host,$rings);
		
		# Compare host calculated trigger with current item and create, update item as required
		for my $required_trigger (@$required_triggers){
			my $trigger_exist = 0;
			for my $trigger (@{$host->triggers}){
				if ($required_trigger->equal($trigger)){
					$up_to_date_triggers += 1;
					$required_trigger->id($trigger->id);
					$trigger_exist = 1;
					last;
				}
				elsif($required_trigger->description eq $trigger->description){
					$updated_triggers += 1;
					$required_trigger->id($trigger->id);
					$trigger = $required_trigger;
					print "INFO Updating zabbix trigger '$required_trigger->{description}' on host $host->{name}\n" if($debug);
					$required_trigger->update($zabbix);
					$trigger_exist = 1;
					last;
				}
			}
			if (!$trigger_exist){
				$created_triggers += 1;
				print "INFO Creating zabbix trigger '$required_trigger->{description}' on host $host->{name}\n" if($debug);
				$required_trigger->create($zabbix);
				$required_trigger->add_dependencie($zabbix, $ping_trigger_id) if($ping_trigger_id);
			}
		}

		print "Statistics for host '$host->{name}':
		Up-to-date items: $up_to_date_items
		Created items: $created_items
		Updated items: $updated_items
		Deleted items: $deleted_items

		Up-to-date triggers: $up_to_date_triggers
		Created triggers: $created_triggers
		Updated triggers: $updated_triggers" if ($statistics);
		print "\n" if($debug or $statistics); 
	}
	else{
		if(!$error){
			print "Host '$host->{name}' has no rings configured\n" if($debug); 
		}
	}
}

#Delete [Auto RRPP] item link to hosts not in the @RRPP_groups
my $request = $zabbix->do(
	'item.get',
	{
		output =>[qw(itemid name hostid)],
		search =>
		{
			name=> "[Auto RRPP]*",
		},
		searchWildcardsEnabled => 'true'
	}
);

for my $item (@$request){
	my $delete = 1;
	for my $host (@$hosts_ref){
		if ($host->id == $item->{hostid}){
			$delete = 0;
		}
	}
	if ($delete){
		print "Deleting Item $item->{name}\n";
		my $request = $zabbix -> do(
			'item.delete',
			{
				params => $item->{itemid}
			}
		);
	}
}

sub calculate_items_from_rings{
	@_ == 2 or croak "Bad number of arguments";
	my $host = shift;
	my $rings = shift;

	my @items;

	my $item_delay = $host->get_macro_by_name('{$RRPP_ITEM_DELAY}');
	if(!$item_delay){
		print "WARNING No RRPP item delay defined for host '$host->{name}' using default delay of 60 second\n" if($debug);
		$item_delay = RRPP_ITEM_DELAY;
	}

	my $snmp_community = $host->get_macro_by_name('{$SNMP_COMMUNITY}');
	if(!$snmp_community){
		$snmp_community = SNMP_COMMUNITY;
	}
	#Item are created for every ring
	for my $ring ( @$rings){
		if ($ring->primary_port_status_oid){
			my $ring_description = "RRPP Ring $ring->{id} Domain $ring->{domain}";
			my $item_name = "[Auto RRPP] $ring->{primary_port_desc} Status ($ring_description)";
			my $item = myZabbix::Item->new(
				id => 0,
				interfaceid => $host->{interfaceid},
				hostid => $host->{id},
				name => $item_name,
				type => 4,
				data_type=> 0,
				value_type => 3,
				key => $ring->primary_port_status_oid,
				delay => $item_delay,
				snmp_community => $snmp_community,
				snmp_oid => $ring->primary_port_status_oid,
				);
			push @items, $item; 
		}
		if ($ring->secondary_port_status_oid){
			my $ring_description = "RRPP Ring $ring->{id} Domain $ring->{domain}";
			my $item_name = "[Auto RRPP] $ring->{secondary_port_desc} Status ($ring_description)";
			my $item = myZabbix::Item->new(
				id => 0,
				interfaceid => $host->{interfaceid},
				hostid => $host->{id},
				name => $item_name,
				type => 4,
				data_type=> 0,
				value_type => 3,
				key => $ring->secondary_port_status_oid,
				delay => $item_delay,
				snmp_community => $snmp_community,
				snmp_oid => $ring->secondary_port_status_oid,
				);
			push @items, $item; 
		}
	}
	return \@items;
}


sub calculate_triggers_from_rings{
	@_ == 2 or croak "Bad number of arguments";
	my $host = shift;
	my $rings = shift;

	my @triggers;
	my $host_name = $host->name;

	my $priority_rrpp_open = $host->get_macro_by_name('{$PRIORITY_RRPP_OPEN}');
	if(!defined($priority_rrpp_open)){
		print "WARNING No priority RRPP open defined for host '$host->{name}' using default priority of 2 (Warning)\n" if($debug);
		$priority_rrpp_open = PRIORITY_RRPP_OPEN;
	}

	for my $ring (@$rings){
		my $trigger_description = "RRPP Ring $ring->{id} Domain $ring->{domain} is open";
		my $trigger_expression;
		if($ring->primary_port_status_oid && $ring->secondary_port_status_oid){
			$trigger_expression = "{$host_name:$ring->{primary_port_status_oid}.last(#1)}<>1 and {$host_name:$ring->{secondary_port_status_oid}.last(#1)}<>1";
		}
		elsif($ring->primary_port_status_oid && !$ring->secondary_port_status_oid){
			$trigger_expression = "{$host_name:$ring->{primary_port_status_oid}.last(#1)}<>1";
		}
		else{
			$trigger_expression = "{$host_name:$ring->{secondary_port_status_oid}.last(#1)}<>1";
		}
		my $trigger = myZabbix::Trigger->new(
			id => 0,
			description => $trigger_description,
			expression => $trigger_expression,
			priority => $priority_rrpp_open
			);
		push @triggers, $trigger;

		}
	return \@triggers;
}

=pod 

=encoding utf8

=head1 NAME

zbxdynrrpp.pl - Create dynamically Zabbix items and triggers for monitoring RRPP rins

=head1 DESCRIPTION

This script will automatically create items and triggers on a Zabbix server to monitor RRPP ring.
The hosts on which the script will be runned need to be in a specific Zabbix group.
The script will retrieve the ring aggregation configured on the switch with SNMP requests.

=head1 ARGUMENTS

=over 4

=item help -h --help 
	
Display the help message

=item version -v --version

Display the version message

=item path configuration file -p

Path to the configuration file

=item create -c --create-interface

Create SNMP interface if noexistent

=item statistics -s

Display the statistics per host

=item debug -d

Display the debug messages

=back

=head1 CONFIGURATION FILE

The configuration file is written in YAML. It should contains the Zabbix username and password 
for using the API as well a the url for requesting the API. It should also provided the groups of hosts
on which the script will be runned.

Here are a example of configuration file:

	---
	zabbix_username: Admin
	zabbix_password: zabbix
	zabbix_url: http://192.168.0.100/zabbix/api_jsonrpc.php
	RRPP_groups:
  	- RRPP_DYN


=head1 AUTHOR

Romain CYRILLE

=head1 LICENSE

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

=cut
