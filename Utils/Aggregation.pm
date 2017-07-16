package Utils::Aggregation;
use Moose;
use strict;
use warnings;

has 'id' => (is=>'rw', required => 1);
has 'description' => (is=>'rw');
has 'interface_oids' => (is=>'rw',default => sub{[]});

1;

=pod

=encoding utf8

=head1 NAME

Utils::Aggregation - Object for representing a link aggregation (LACP)

=head1 DESCRIPTION

Hold the information about the SNMP representation of a link aggregations

=head1 ATTRIBUTES

=over 4

=item id

The SNMP index of the aggregation 

=item description

The SNMP description of the aggregation

=item interface_oids

A list of SNMP oids which are the oids of the interfaces link to the aggregation.

=back

=head1 AUTHOR

Romain CYRILLE

=head1 LICENSE

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
