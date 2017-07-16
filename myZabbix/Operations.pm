package myZabbix::Operations;
use strict;
use warnings;
use Carp;
use myZabbix::Host;
use myZabbix::Macro;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 0.1;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(get_hosts_in_groups);
%EXPORT_TAGS = (All=> [qw(&get_hosts_in_groups)]);


sub get_hosts_in_groups{
	@_ == 2 or croak "Bad number of arguments";

	my $zabbix_ref = shift;
	my $groups_ref = shift;

	my $request = $zabbix_ref->do(
		'hostgroup.get',
		{
			output=>['groupid'],
			filter=>{
						name=>@$groups_ref
					}
		}
	);
	
	my @group_ids;
	for my $group (@$request){
		push @group_ids, $group->{groupid};
	}
	if(@group_ids){
		$request = $zabbix_ref->do(
		    'host.get',
		    {
		        output    => [qw(hostid host)],
		        groupids => @group_ids,
		    }
		);

		my @hosts;
		for my $host (@$request){
		 	  push @hosts, myZabbix::Host->new(id => $host->{hostid}, name => $host->{host}) ;
		}
		return \@hosts;
	}
	return undef;
}



=pod 

=encoding utf8

=head1 NAME

myZabbix::Operations - A module to retrieve information from a Zabbix server

=head1 DESCRIPTION

Retrieve information from a Zabbix server using the Zabbix API.

=head1 METHODS

get_hosts_in_groups()

	Construct a list of the zabbix hosts that are in specific group
	Params:
		zabbix_ref 		- A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API
		groups_ref 		- A reference to a list with the Zabbix groups from which to retrieve the hosts

	Returns:
		A reference to a list which contains myZabbix::Host objects. 

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
