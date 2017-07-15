package myZabbix::Item;
use Moose;
use Carp;

has 'id' => (is => 'rw', required => 1);
has 'name' => (is => 'rw');
has 'hostid' => (is => 'rw');
has 'interfaceid' => (is => 'rw');
has 'key' => (is => 'rw');
has 'type' => (is => 'rw');
has 'data_type' => (is => 'rw');
has 'value_type' => (is => 'rw');
has 'snmp_community' => (is => 'rw');
has 'snmp_oid' => (is => 'rw');
has 'delay' => (is => 'rw');


sub equal{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $item_ref = shift;
	return	$self->name eq $item_ref->name &&
            $self->hostid == $item_ref->hostid &&
			$self->interfaceid == $item_ref->interfaceid &&
			$self->key eq $item_ref->key &&
			$self->type == $item_ref->type &&
			$self->data_type == $item_ref->data_type &&
            $self->value_type == $item_ref->value_type &&
			$self->snmp_community eq $item_ref->snmp_community &&
			$self->snmp_oid eq $item_ref->snmp_oid &&
            $self->delay == $item_ref->delay;  
}

sub get{
    @_ == 2 or croak "Bad number of arguments";
    my $self = shift;
    my $zabbix_ref = shift;

    my $request = $zabbix_ref -> do(
        'item.get',
        {
            output => [qw(itemid interfaceid name hostid type key_ value_type data_type snmp_community snmp_oid delay)],
            itemsids => [ $self->id ]
        }
        );

    my $item_ref = $request->[0];
    $self->interfaceid( $item_ref->{interfaceid} );
    $self->name( $item_ref->{name} );
    $self->hostid( $item_ref->{hostid} );
    $self->type( $item_ref->{type} );
    $self->key( $item_ref->{key_} );
    $self->value_type( $item_ref->{value_type} );
    $self->data_type( $item_ref->{data_type} );
    $self->snmp_community( $item_ref->{snmp_community} );
    $self->snmp_oid( $item_ref->{snmp_oid} );
    $self->delay( $item_ref->{delay} );
}


sub create{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $zabbix_ref = shift;
	my $request = $zabbix_ref -> do(
    	'item.create',
    	{
    		hostid => $self->hostid,
    		interfaceid => $self->interfaceid,
    		name => $self->name,
    		type => $self->type,
    		data_type => $self->data_type,
    		key_ => $self->key,
    		delay => $self->delay,
    		value_type=> $self->value_type,
    		snmp_community => $self->snmp_community,
    		snmp_oid => $self->snmp_oid
    	}
    );
    $self->id( ${$request->{itemids}}[0] );
}

sub update{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $zabbix_ref = shift;
	my $request = $zabbix_ref -> do(
    	'item.update',
    	{
    		itemid => $self->id,
    		hostid => $self->hostid,
    		interfaceid => $self->interfaceid,
    		name => $self->name,
    		type => $self->type,
    		data_type => $self->data_type,
    		key_ => $self->key,
    		delay => $self->delay,
    		value_type=> $self->value_type,
    		snmp_community => $self->snmp_community,
    		snmp_oid => $self->snmp_oid
    	}
    );
};

sub delete{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $zabbix_ref = shift;
	my $request = $zabbix_ref -> do(
    	'item.delete',
    	{
    		params => $self->id
    	}
    );
}

1;

=pod

=encoding utf8

=head1 NAME

myZabbix::Item - Object for representing a Zabbix item

=head1 DESCRIPTION

Represent a Zabbix item and provide methods to get, create, update and delete item with the Zabbix API
 
=head1 ATTRIBUTES

=over 4

=item id

The item id 

=item name

The item name

=item hostid
    
The id of the host linked to the item

=item interfaceid

The id of the interface linked to the item

=item key

The key expression of the item

=item type

The type of the item

=item data_type

The data type returned by the item

=item value_type

The value type of the data returned by the item

=item snmp_community

The SNMP community used by the item

=item snmp_oid

The SNMP object retrieved by the item

=item delay

The delay of item

=back

=head1 METHODS

equal()

    Indicates if a other item object is equal to this one (the id is not compared)
    Params:
        A reference to a item object
    Returns:
        A boolean indicating if the object are equal or not

get()

    Retrieve the Zabbix item from the Zabbix server, the id of the item need to be correct
    Params:
        A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

create()

    Create the Zabbix item on the Zabbix server and update the id of the object with the one returned by the server
    Params:
        A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

update()

    Update the Zabbix item on the Zabbix server
    Params:
        A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

delete()

    Delete the Zabbix item on the Zabbix server
    Params:
        A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

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
