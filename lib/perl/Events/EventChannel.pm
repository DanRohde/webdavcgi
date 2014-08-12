#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################
package Events::EventChannel;

sub new {
	my $class = shift;
	my $self  = {};
	return bless $self, $class;
}

sub addEventListener {
	my ( $self, $event, $eventListener ) = @_;
	if ( defined $eventListener ) {
		$eventListener->isa('Events::EventListener')
		  or die("I need a Events::EventListener for $event");
	}
	
	$$self{$event || 'ALL'} = [] unless $$self{$event || 'ALL'};
	
	if ( !defined $event) {
		push(@{$$self{ALL}}, $eventListener);
	}
	elsif ( ref($event) eq 'ARRAY' ) {
		foreach my $e ( @{$event} ) {
			push(@{$$self{$e}}, $eventListener);
		}
	}
	else {
		push(@{$$self{$event}}, $eventListener);
	}
	return 1;
}

sub broadcastEvent {
	#my ($self, $event, $data) = @_;
	my $self      = shift;
	my $event     = shift;
	my @listeners = ( @{ $$self{$event} || () }, @{ $$self{ALL} } );
	foreach my $listener (@listeners) {
		eval { $listener->receiveEvent( $event, @_ ); };
		warn $@ if ($@);
	}
}

1;
