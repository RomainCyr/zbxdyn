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

=cut
