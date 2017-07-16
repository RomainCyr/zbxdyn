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

=cut
