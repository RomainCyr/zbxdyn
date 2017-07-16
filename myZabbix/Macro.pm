package myZabbix::Macro;
use Moose;
use Carp;

has 'id' => (is => 'rw', required => 1);
has 'macro' => (is => 'rw');
has 'value' => (is => 'rw');
has 'is_global' => (is => 'rw', required => 1);

1;

=pod

=encoding utf8

=head1 NAME

myZabbix::Macro - Object for representing a Zabbix Macro

=head1 DESCRIPTION

Represent a Zabbix Macro
 
=head1 ATTRIBUTES

=over 4

=item id

The macro id 

=item macro

The macro name

=item value

The macro value

=item is_global

Indicate if the macro is global or not

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