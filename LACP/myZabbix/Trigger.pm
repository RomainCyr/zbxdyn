package myZabbix::Trigger;
use Moose;
use Carp;


has 'id' => (is => 'rw', required => 1);
has 'description' => (is => 'rw');
has 'expression' => (is => 'rw');
has 'priority' => (is => 'rw');
has 'dependencies' => (is => 'rw',default => sub{[]});



sub equal{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $item = shift;
	return	$self->description eq $item->description &&
			$self->expression eq $item->expression &&
			$self->priority == $item->priority;  
}

sub get{
    @_ == 2 or croak "Bad number of arguments";
    my $self = shift;
    my $zabbix_ref = shift;

    my $request = $zabbix_ref -> do(
        'trigger.get',
        {
            output => [qw(triggerid description expression priority)],
            triggerid => [ $self->id ],
            expandExpression=> 'true'
        }
        );

    my $trigger_ref = $request->[0];
    $self->description( $trigger_ref->{description} );
    $self->expression( $trigger_ref->{expression} );
    $self->priority( $trigger_ref->{priority} );
}

sub create{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $zabbix_ref = shift;
	my $request = $zabbix_ref -> do(
    	'trigger.create',
    	{
    		description => $self->description,
    		expression => $self->expression,
    		priority => $self->priority,
    	}
    );
    $self->id( ${$request->{triggerids}}[0] );
}

sub update{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $zabbix_ref = shift;
	my $request = $zabbix_ref -> do(
    	'trigger.update',
    	{
    		triggerid => $self->id,
    		description => $self->description,
    		expression => $self->expression,
    		priority => $self->priority,
    	}
    );
};

sub delete{
	@_ == 2 or croak "Bad number of arguments";
	my $self = shift;
	my $zabbix_ref = shift;
	my $request = $zabbix_ref -> do(
    	'trigger.delete',
    	{
    		params => $self->id
    	}
    );
}

sub add_dependencie{
    @_ == 3 or croak "Bad number of arguments";
    my $self = shift;
    my $zabbix_ref = shift;
    my $dependencie_id = shift;

    my $request = $zabbix_ref -> do(
        'trigger.adddependencies',
        {
            triggerid => $self->id,
            dependsOnTriggerid => $dependencie_id
        }
    );
};

1;

=pod

=encoding utf8

=head1 NAME

myZabbix::Trigger - Object for representing a Zabbix trigger

=head1 DESCRIPTION

Represent a Zabbix Trigger and provide methods to get, create, update and delete trigger with the Zabbix API
 
=head1 ATTRIBUTES

=over 4

=item id

The trigger id 

=item description

The trigger description

=item expression

The trigger expression

=item priority

The trigger priority

=item dependencies

The trigger dependencies

=back

=head1 METHODS

equal()

    Indicates if a other trigger object is equal to this one (the id is not compared)
    Params:
        A reference to a trigger object
    Returns:
        A boolean indicating if the object are equal or not

get()

    Retrieve the Zabbix trigger from the Zabbix server, the id of the trigger need to be correct
    Params:
        A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

create()

    Create the Zabbix trigger on the Zabbix server and update the id of the object with the one returned by the server
    Params:
        A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

update()

    Update the Zabbix trigger on the Zabbix server
    Params:
        A reference to a initialized Zabbix::Tiny object used for requesting the Zabbix API

delete()

    Delete the Zabbix trigger on the Zabbix server
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
