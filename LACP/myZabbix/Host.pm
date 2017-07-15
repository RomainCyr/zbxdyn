package myZabbix::Host;
use Moose;
use Carp;
use myZabbix::Item;
use myZabbix::Trigger;
use myZabbix::Macro;
has 'id' => (is => 'rw', required => 1);
has 'name' => (is => 'rw', required => 1);
has 'interfaceid' => (is => 'rw');
has 'ip' => (is => 'rw');
has 'snmp_port' => (is => 'rw', default => 161);
has 'items' => (is => 'rw',default => sub{[]});
has 'triggers' => (is => 'rw', default => sub{[]});
has 'macros' => (is => 'rw',default => sub{[]});


sub retrieve_items{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $zabbix_ref = shift;

	my $request = $zabbix_ref -> do(
  		'item.get',
  		{
  			output => [qw(itemid name interfaceid hostid type key_ value_type data_type snmp_community snmp_oid delay)],
  			hostids => [$self->id]
  		}
  		);

  	for my $item_ref (@$request){
  		my $zabbix_item = myZabbix::Item->new(
  			id => $item_ref->{itemid},
  			name => $item_ref->{name},
  			hostid => $item_ref->{hostid},
  			interfaceid => $item_ref->{interfaceid},
  			key => $item_ref->{key_},
  			type => $item_ref->{type},
  			data_type => $item_ref->{data_type},
  			value_type => $item_ref->{value_type},
  			snmp_community => $item_ref->{snmp_community},
  			snmp_oid => $item_ref->{snmp_oid},
  			delay => $item_ref->{delay}  
  			);
  		push @{$self->items}, $zabbix_item; 
  	}	
}

sub retrieve_triggers{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $zabbix_ref = shift;

	my $request = $zabbix_ref -> do(
  		'trigger.get',
  		{
  			output => [qw(triggerid description expression priority)],
  			hostids => [$self->id],
  			expandExpression=> 'true',
  		}
  		);

  	for my $trigger_ref (@$request){
  		my $zabbix_trigger = myZabbix::Trigger->new(
  			id => $trigger_ref->{triggerid},
  			description => $trigger_ref->{description},
  			expression => $trigger_ref->{expression},
  			priority => $trigger_ref->{priority}
  			);

  		push @{$self->triggers}, $zabbix_trigger; 
  	}
}

sub retrieve_macros{
  @_ == 2 or croak "Bad number of arguments";
  my $self = shift;
  my $zabbix_ref = shift;

  my $request = $zabbix_ref->do(
      'usermacro.get',
      {
        globalmacro => 'false',
        hostids => [$self->id]
      }
  );

  for my $macro_ref (@$request){
    my $zabbix_macro = myZabbix::Macro->new(
      id => $macro_ref->{hostmacroid},
      macro => $macro_ref->{macro},
      value => $macro_ref->{value},
      is_global => 0
      );
    push @{$self->macros}, $zabbix_macro;
  }
}

sub retrieve_snmp_interface{
  @_ > 2 or croak "Bad number of arguments";
  my $self = shift;
  my $zabbix_ref = shift;
  my $create = shift;

  my $request = $zabbix_ref->do(
       'hostinterface.get',
       {
         output =>[qw(interfaceid hostid ip port type main)],
         hostids => [$self->id]
       }
   );

  for my $interface (@$request){
      # Get the IP from the main SNMP interface (type == 2) 
      if ($interface->{type} == 2 and $interface->{main} == 1) {
        $self->ip( $interface->{ip} );
        $self->snmp_port( $interface->{port} ); 
        $self->interfaceid( $interface->{interfaceid} );
      }
  }
  #Create SNMP interface if not defined
  if($create && !defined($self->ip)){
    for my $interface (@$request){
      # Get the IP from the main agent interface (type == 1) 
      if ($interface->{type} == 1 and $interface->{main} == 1) {
        $request = $zabbix_ref->do( 
          'hostinterface.create',
          {
            hostid => $self->id,
            dns => "",
            ip => $interface->{ip},
            main => 1,
            port => 161,
            type => 2,
            useip => 1
          }
        );
        $self->ip( $interface->{ip} );
        $self->snmp_port( 161 ); 
        $self->interfaceid(${$request->{interfaceids}}[0]  );
      }
    }
  }
}

sub get_macro_by_name{
  @_ == 2 or croak "Bad number of arguments";
  my $self = shift;
  my $macro_name = shift;

  for my $macro (@{$self->macros}){
    if($macro->{macro} eq $macro_name){
      return $macro->{value};
      last;
    }
  }
  return undef;
}

1;

=pod

=encoding utf8

=head1 NAME

myZabbix::Host - Object for representing a Zabbix host

=head1 DESCRIPTION

Represent a zabbix host object and provide methods to retrieve its dependencies (items, triggers, macros) 


=head1 ATTRIBUTES

=over 4

=item id

The host id

=item name

The host name

=item interfaceid

The interfaceid of the main SNMP host interface

=item ip

The host ip address

=item snmp_port

The host SNMP port

=item items

The list of items linked to the host

=item triggers

The list of trigger linked to the host

=item macros

The list of macro linked to the host

=back

=head1 METHODS

retrieve_items()

  Construct a list of the Zabbix items linked to the host and save it in the items attribute
  Params:
    A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

retrieve_triggers()

  Construct a list of the Zabbix triggers linked to the host and save it in the triggers attribute
  Params:
    A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

retrieve_macros()

  Construct a list of the Zabbix macros linked to the host and save it in the macros attribute
  Params:
    A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

retrieve_snmp_interface()

  Retrieve the main SNMP interface of the host and save it in the interfaceid, ip and port attributes
  Params:
    zabbix_ref  - A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API
    create      - A boolean to allow SNMP interface creation

get_macro_by_name()

  Browse the macro attribute and return a macro by its name
  Params:
    The macro name
  Returns:
    A macro object

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