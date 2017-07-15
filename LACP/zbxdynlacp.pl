#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use Zabbix::Tiny;
use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);
use YAML::XS qw(LoadFile);
use Utils::HPSNMP qw(HP_get_switch_aggregations);
use myZabbix::Operations qw(get_hosts_in_groups);
use vars qw($VERSION);
$VERSION = 0.1;

use Data::Dumper;

use constant{
	LACP_ITEM_DELAY => 60,
	PRIORITY_LACP_DOWN => 5,
	PRIORITY_LACP_PARTIALLY_DOWN => 2,
	SNMP_COMMUNITY => 'public',
	SNMP_TIMEOUT =>5 ,
	SNMP_RETRIES => 0
};


# Handle command line arguments
my $configuration_file;
my $help;
my $version;
my $debug;
my $statistics;

GetOptions(
	'help|h' => \$help,
	'version|v' => \$version,
	'c=s' => \$configuration_file,
	's' => \$statistics,
	'd' => \$debug
)or die("Error in command line arguments\n");

if($version){
	print "$0 version $VERSION\n";
	exit 0;
}

if($help){
	print
	"Usage:\n\t$0 [-c <configuration_file>]\nOptions:
	-h --help \t\tShow this Screen		
	-v --version \tVersion of the scrip
	-c \t\tPath to the configuration file
	-s \t\tShow statistics per host
	-d \t\tDebug mode\n";
	exit 0;
}

if(!$configuration_file){
	$configuration_file = '/etc/zabbix/auto_lacp.conf';
	print "INFO Using default path for configuration file: $configuration_file\n" if($debug);
}

#Load configuration file
my $config = LoadFile($configuration_file);
my $zabbix_username = $config->{zabbix_username};
my $zabbix_password = $config->{zabbix_password};
my $zabbix_url = $config->{zabbix_url};
my @LACP_groups = $config->{LACP_groups};

#Connect to Zabbix server to retrieve authentication token
print "INFO Connecting to Zabbix Server\n" if($debug);
my $zabbix = Zabbix::Tiny->new(
	server   => $zabbix_url,
	password => $zabbix_password,
	user     => $zabbix_username
);

#Construct list of Zabbix Host
print "INFO Retrieving Zabbix Hosts\n" if($debug);
my $hosts_ref = get_hosts_in_groups($zabbix,\@LACP_groups);

for my $host (@$hosts_ref){

	print "INFO Retrieving Zabbix items for host $host->{name}\n" if($debug);
	$host->retrieve_items($zabbix);
	print "INFO Retrieving Zabbix triggers for host $host->{name}\n" if($debug);
	$host->retrieve_triggers($zabbix);
	print "INFO Retrieving Zabbix macros for host $host->{name}\n" if($debug);
	$host->retrieve_macros($zabbix);
	print "INFO Retrieving Zabbix snmp interfaces for host $host->{name}\n" if($debug);
	$host->retrieve_snmp_interface($zabbix);

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
	
	print "INFO Retrieving aggregation on switch '$host->{name}' with IP $host->{ip}\n" if($debug);
	my $aggregation;
	my $error;
	eval{
		$aggregation = HP_get_switch_aggregations(
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

	if($aggregation){
		my $up_to_date_items = 0;
		my $created_items = 0;
		my $updated_items = 0;
		my $deleted_items = 0;
		my $up_to_date_triggers = 0;
		my $created_triggers = 0;
		my $updated_triggers = 0;

		my $required_items = calculate_items_from_aggregations($host,$aggregation);
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
			my $regex = qr/\[Auto LACP\]/p;
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
			my $regex = qr/icmpping\./p;
			if($trigger->expression =~ /$regex/g){
				$ping_trigger_id = $trigger->id;
			}
		}
		if(!$ping_trigger_id && $debug){
			print "WARNING No ping check trigger defined on host $host->{name}, no ping dependencie will be set\n";
		}

		my $required_triggers = calculate_triggers_from_aggregations($host,$aggregation);
		
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
			print "Host '$host->{name}' has no aggregation configured\n"; 
		}
	}
}
#Delete [Auto LACP] item link to hosts not in the @LACP_groups
my $request = $zabbix->do(
	'item.get',
	{
		output =>[qw(itemid name hostid)],
		search =>
		{
			name=> "[Auto LACP]*",
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

sub calculate_items_from_aggregations{
	@_ == 2 or croak "Bad number of arguments";
	my $host = shift;
	my $aggregations = shift;

	my @items;

	my $item_delay = $host->get_macro_by_name('{$LACP_ITEM_DELAY}');
	if(!$item_delay){
		print "WARNING No LACP item delay defined for host '$host->{name}' using default delay of 60 second\n" if($debug);
		$item_delay = LACP_ITEM_DELAY;
	}

	my $snmp_community = $host->get_macro_by_name('{$SNMP_COMMUNITY}');
	if(!$snmp_community){
		$snmp_community = SNMP_COMMUNITY;
	}
	#Items need to be created for every interface of an aggregation
	for my $aggregation (keys %$aggregations){
		my %interface_oids = @{$aggregations->{$aggregation}->interface_oids};
		for my $oid (keys %interface_oids){
			my $aggregation_description = $aggregations->{$aggregation}->description;
			my $item_name = "[Auto LACP] $interface_oids{$oid} Status ($aggregation_description)";
			my $item = myZabbix::Item->new(
				id => 0,
				interfaceid => $host->{interfaceid},
				hostid => $host->{id},
				name => $item_name,
				type => 4,
				data_type=> 0,
				value_type => 3,
				key => $oid,
				delay => $item_delay,
				snmp_community => $snmp_community,
				snmp_oid => $oid,
				);
			push @items, $item; 
		}   
	}
	return \@items;
}


sub calculate_triggers_from_aggregations{
	@_ == 2 or croak "Bad number of arguments";
	my $host = shift;
	my $aggregations = shift;

	my @triggers;
	my $host_name = $host->name;

	my $priority_LACP_down = $host->get_macro_by_name('{$PRIORITY_LACP_DOWN}');
	if(!defined($priority_LACP_down)){
		print "WARNING No priority LACP down defined for host '$host->{name}' using default priority of 5 (Disaster)\n" if($debug);
		$priority_LACP_down = PRIORITY_LACP_DOWN;
	}
	my $priority_LACP_partially_down = $host->get_macro_by_name('{$PRIORITY_LACP_PARTIALLY_DOWN}');
	if(!defined($priority_LACP_partially_down)){
		print "WARNING No priority LACP partially down defined for host '$host->{name}' using default priority of 2 (Warning)\n" if($debug);
		$priority_LACP_partially_down = PRIORITY_LACP_PARTIALLY_DOWN;
	}

	for my $aggregation (keys %$aggregations){
		my $trigger_expression_1 ;
		my $trigger_expression_2 ;
		my %interface_oids = @{$aggregations->{$aggregation}->interface_oids};

		if (scalar(keys %interface_oids)>1){
			for my $oid (sort keys %interface_oids){

				if($trigger_expression_1 && $trigger_expression_2){
					$trigger_expression_1 = $trigger_expression_1 . " or {$host_name:$oid.last(#1)}<>1";
					$trigger_expression_2 = $trigger_expression_2 . " and {$host_name:$oid.last(#1)}<>1";
				}
				else{
					$trigger_expression_1 = "{$host_name:$oid.last(#1)}<>1";
					$trigger_expression_2 = $trigger_expression_1;
				}
			}

			my $trigger_expression_degraded = "($trigger_expression_1) and not ($trigger_expression_2)";
			my $trigger_expression_down = "$trigger_expression_2";
			my $aggregation_description = $aggregations->{$aggregation}->description;
			my $trigger_description_degraded = "[Auto LACP] ".$aggregation_description . " is partially down";
			my $trigger_description_down = "[Auto LACP] ".$aggregation_description . " is down";
			my $trigger_degraded= myZabbix::Trigger->new(
				id => 0,
				description => $trigger_description_degraded,
				expression => $trigger_expression_degraded,
				priority => $priority_LACP_partially_down
				);
			push @triggers, $trigger_degraded;

			my $trigger_down = myZabbix::Trigger->new(
				id => 0,
				description => $trigger_description_down,
				expression => $trigger_expression_down,
				priority => $priority_LACP_down
				);
			push @triggers, $trigger_down;
		}
		else{
			for my $oid (keys %interface_oids){
				my $trigger_expression_down = "{$host_name:$oid.last(#1)}<>1";
				my $aggregation_description = $aggregations->{$aggregation}->description;
				my $trigger_description_down = "[Auto LACP] ".$aggregation_description . " is down";
				my $trigger_down = myZabbix::Trigger->new(
					id => 0,
					description => $trigger_description_down,
					expression => $trigger_expression_down,
					priority => $priority_LACP_down
					);
				push @triggers, $trigger_down;
			}
		}
	}
	return \@triggers;
}

=pod 

=encoding utf8

=head1 NAME

zbxdynlacp.pl - Create dynamically Zabbix items and triggers for monitoring link aggregations

=head1 DESCRIPTION

This script will automatically create items and triggers on a Zabbix server to monitor link aggregation.
The hosts on which the script will be runned need to be in a specific Zabbix group.
The script will retrieve the link aggregation configured on the switch with SNMP requests.

=head1 ARGUMENTS

=over 4

=item help -h --help 
	
Display the help message

=item version -v --version

Display the version message

=item configuration file -c

Path to the configuration file

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
	LACP_groups:
  	- LACP_DYN


=head1 AUTHOR

Romain CYRILLE

=head1 LICENSE

This file is part of zbxdynlacp.

Zbxdynlacp is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
any later version.

Zbxdynlacp is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Zbxdynlacp.  If not, see <http://www.gnu.org/licenses/>.

=cut
