package Utils::Ring;
use Moose;
use strict;
use warnings;

has 'id' => (is=>'rw', required => 1);
has 'domain' => (is=>'rw', required => 1);
has 'primary_port_status_oid' => (is=>'rw');
has 'primary_port_desc' => (is=>'rw');
has 'secondary_port_status_oid' => (is=> 'rw');
has 'secondary_port_desc' => (is=> 'rw');

1;

=pod

=encoding utf8

=head1 NAME

Utils::Ring - Object for representing a RRPP ring

=head1 DESCRIPTION

Hold the information about the SNMP representation of a RRPP ring

=head1 ATTRIBUTES

=over 4

=item id

The ring id

=item description

The ring domain

=item primary_port_status_oid

The SNMP object for the status of the primary port

=item primary_port_desc_oid

The SNMP description of the primary port

=item secondary_port_status_oid

The SNMP object for the status of the secondary port

=item secondary_port_desc_oid

The SNMP description of the secondary port

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
