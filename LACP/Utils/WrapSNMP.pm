package Utils::WrapSNMP;
use strict;
use warnings;
use Carp;
use Net::SNMP;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 0.1;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(snmp_get snmp_bulk_get snmp_get_subtree);
%EXPORT_TAGS = (All=> [qw(&snmp_get &snmp_bulk_get &snmp_get_subtree)]);

sub snmp_get_subtree{
	my %args = @_;
	my %defaults = (
			port => 161,
			community => "public", 
			retries => 0, 
			timeout => 5, 
			maxrepetitions => 128
	);

	croak "Hostname is required" if !defined $args{hostname};
	croak "Oid is required" if !defined $args{oid};

	foreach(keys %defaults){
		if (!defined ($args{$_})){
			$args{$_} = $defaults{$_};
		} 
	}

	my $oid_tmp;
	my $all_retrieved = 0;
	my $last_index;
	my %result;
	
	until($all_retrieved){
		if(defined $last_index){
			$oid_tmp = $args{oid} . ".$last_index";
		}
		else{
			$oid_tmp = $args{oid};
			$last_index = 0;
		}

		my $response = snmp_bulk_get(
			hostname => $args{hostname},
			port => $args{port},
			community => $args{community},
			version => 2,
			oids => [$oid_tmp],
			retries => $args{retries},
			timeout => $args{timeout},
			maxrepetitions => $args{maxrepetitions}
			);

		for my $key (keys %{$response}){
			# The entire subtree is retrieved when the objects received do not start with the same oid root
			if( index($key,$args{oid}) != 0){
				$all_retrieved = 1;
			}
			else{
				$result{$key} = $response->{$key};
				my $index = substr($key,length($args{oid})+1);
				if ($index > $last_index){
					$last_index = $index;
				}
			}
		}
	}
	return \%result;
}


sub snmp_get{
	my %args = @_;
	my %defaults = (
			port => 161,
			community => "public", 
			retries => 0, 
			timeout => 5
	);

	croak "Hostname is required" if !defined $args{hostname};
	croak "Version is required" if !defined $args{version};
	croak "Oids is required" if !defined $args{oids};

	foreach(keys %defaults){
		if (!defined ($args{$_})){
			$args{$_} = $defaults{$_};
		} 
	}

	my ($session, $error) = Net::SNMP->session(
		retries => $args{retries},
		version => $args{version},
		hostname => $args{hostname},
		port => $args{port},
		community => $args{community},
		timeout => $args{timeout}
	);
	die "error initializing SMMP session ($error)" if !defined($session);
	
	my $response  = $session->get_request(
			varbindlist => $args{oids}
		);	
	my $err = $session->error;
	die "error sending bulk request ($err)" if $err;
	return $response;
}

sub snmp_bulk_get{
	my %args = @_;
	my %defaults = (
			port => 161,
			community => "public", 
			retries => 0, 
			timeout => 5,
			nonrepeaters => 0, 
			maxrepetitions =>10, 
	);

	croak "Hostname is required" if !defined $args{hostname};
	croak "Version is required" if !defined $args{version};
	croak "Oids is required" if !defined $args{oids};

	foreach(keys %defaults){
		if (!defined ($args{$_})){
			$args{$_} = $defaults{$_};
		} 
	}

	my ($session, $error) = Net::SNMP->session(
		retries => $args{retries},
		version => $args{version},
		hostname => $args{hostname},
		port => $args{port},
		community => $args{community},
		timeout => $args{timeout}
	);
	die "error initializing SMMP session ($error)" if !defined($session);
	
	my $response  = $session->get_bulk_request(
			nonrepeaters => $args{nonrepeaters},
			maxrepetitions => $args{maxrepetitions},
			varbindlist => $args{oids}
		);	
	my $err = $session->error;
	die "error sending bulk request ($err)" if $err;

	return $response;
}

1;

=pod 

=encoding utf8

=head1 NAME

Utils::WrapSNMP - A module simplify the use of the Net::SNMP module

=head1 DESCRIPTION

Simplify the use of the Net::SNMP module and 

=head1 METHODS

snmp_get_subtree()

	Fetch the entire subtree of a SNMP object using SNMP GETBULK request

	Params:
		hostname 		- The address of the SNMP agent
		oid				- A SNMP object
		[port] 			- The port of the SNMP agent
		[community] 	- The read community
		[timeout] 		- The number of seconds until the request timeout
		[retries]		- The number of retries
		[maxrepetitions]- The maximum number of iterations between two SNMP requests

	Returns:
		A reference to a hash which contains the SNMP objects and their values


snmp_get()
 
	Fetch SNMP objects using the SNMP GET request

	Params:
		hostname 	- The address of the SNMP agent
		oids		- A reference to a list of SNMP objects
		[port] 			- The port of the SNMP agent
		[community] 	- The read community
		[timeout] 		- The number of seconds until the request timeout
		[retries]		- The number of retries

	Returns:
		A reference to a hash which contains the SNMP objects and their values


snmp_bulk_get()	

	Fetch SNMP objects using the SNMP GETBULK request

	Params:
		hostname 		- The address of the SNMP agent
		oids 			- A reference to a list of SNMP objects
		[port] 			- The port of the SNMP agent
		[community] 	- The read community
		[timeout] 		- The number of seconds until the request timeout
		[retries]		- The number of retries
		[nonrepeaters]	- The number of supplied variables that should not be iterated over 	
		[maxrepetitions]- The maximum number of iterations over the repeating variables

	Returns:
		A reference to a hash which contains the SNMP objects and their values

=head1 AUTHOR

Romain CYRILLE

=cut
