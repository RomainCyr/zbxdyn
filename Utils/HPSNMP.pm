package Utils::HPSNMP;
use strict;
use warnings;
use Carp;
use Utils::Aggregation;
use Utils::WrapSNMP qw(:All);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 0.1;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(HP_get_switch_aggregations);
%EXPORT_TAGS = (All=> [qw(&HP_get_switch_aggregations)]);


use constant {
	OID_AGG_PORT_LIST_PORTS => "1.2.840.10006.300.43.1.1.2.1.1",
	OID_AGG_PORT_ATTACHED_AGG_ID => "1.2.840.10006.300.43.1.2.1.1.13",
	OID_IF_OPER_STATUS => "1.3.6.1.2.1.2.2.1.8",
	OID_IF_DESC => "1.3.6.1.2.1.2.2.1.2",
};


sub HP_get_switch_aggregations{
	my %args = @_;
	my %defaults = ( 
		port => 161,
		community=>"public", 
		retries=>0, 
		timeout=>5,
	);

	croak "Hostname is required" if !defined $args{hostname};

	foreach(keys %defaults){
		if (!defined ($args{$_})){
			$args{$_} = $defaults{$_};
		} 
	}

	my %aggregations;

	#Retrieve the ids of aggregation configured on the switch
	my $aggregations_ids = snmp_get_subtree(
		hostname => $args{hostname},
		port => $args{port},
		community => $args{community},
		oid => OID_AGG_PORT_LIST_PORTS,
		retries => $args{retries},
		timeout => $args{timeout},
		maxrepetitions => 10
	);
	# Continue only if the switch have aggregation ports configured
	if($aggregations_ids){
		# Construct a dictionary of aggregation objects with their description
		for my $key (keys %{$aggregations_ids}){
			my $id = substr($key,length (OID_AGG_PORT_LIST_PORTS) +1);
			my $oid_description = OID_IF_DESC . ".$id"; 
			my $response = snmp_get(
				hostname => $args{hostname},
				port => $args{port},
				community => $args{community},
				oids => [$oid_description],
				version => 2
				);

			my $aggregation = Utils::Aggregation->new(
				id => $id, 
				description => $response->{$oid_description}
				);

			$aggregations{$id} =  $aggregation;
		}

		# Retrieve the interfaces attached to the aggregation
		my $aggregation_attached_interfaces = snmp_get_subtree(
			hostname => $args{hostname},
			port => $args{port},
			community => $args{community},
			oid => OID_AGG_PORT_ATTACHED_AGG_ID,
			maxrepetitions => 128,
			retries => $args{retries},
			timeout => $args{timeout}
			);

		for my $key (keys %$aggregation_attached_interfaces){
			# If the port is attached to a aggregation port, 
			# it is add to the dictionnary of aggregation port
			if (grep(/^$aggregation_attached_interfaces->{$key}$/,keys %aggregations)){
				
				my $id = substr($key,length(OID_AGG_PORT_ATTACHED_AGG_ID)+1);
				my $oid_description = OID_IF_DESC . ".$id"; 
				my $oid_oper_status = OID_IF_OPER_STATUS . ".$id";

				my $response = snmp_get(
					hostname => $args{hostname},
					port => $args{port},
					community => $args{community},
					oids => [$oid_description],
					version => 2,
					retries => $args{retries},
					timeout => $args{timeout}
					);

				my $interface_oids = $aggregations{$aggregation_attached_interfaces->{$key}}->interface_oids;
				push @$interface_oids, ($oid_oper_status => $response->{$oid_description});
			}
		}
	}
	return \%aggregations;
}

=pod 

=encoding utf8

=head1 NAME

Utils::HPSNMP - A module to retrieve information on HP switch with SNMP request

=head1 DESCRIPTION

Retrieve information from HP switch with SNMP request, such as link-aggregation or RRPP ring

=head1 METHODS

HP_get_switch_aggregations()

	Construct a list of the aggregations configured on a HP switch
	Params:
		hostname 		- The address of the switch
		[port] 			- The port of the SNMP agent
		[community]		- The SNMP read community
		[timeout] 		- The number of seconds until the SNMP request timeout
		[retries]		- The number of retries

	Returns:
		A reference to a hash which contains Utils::Aggregation objects. 
		The keys of the hash are the aggreagation id and the value are the corresponding Utils::Aggregation objects. 


=head1 AUTHOR

Romain CYRILLE

=cut
