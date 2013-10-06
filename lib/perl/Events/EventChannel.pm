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
	my $self = { };
	return bless $self, $class;
}

sub addEventListener {
	my ($self, $event, $eventListener) = @_;
	if (defined $eventListener) {	
		$eventListener->isa('Events::EventListener') or die("I need a Events::EventListener for $event");
	}
	if (ref($event) eq 'ARRAY') {
		foreach my $e (@{$event}) {
			$$self{$e}{$eventListener} = $eventListener;
		}
	} elsif (ref($event) eq 'HASH') {
		foreach my $e (keys %{$event}) {
			$$event{$e}->isa('Events::EventListener') or die("I need a Events::EventListener for $e");
			$$self{$e}{$$event{$e}} = $$event{$e};
		}
	} else {
		$$self{$event}{$eventListener} = $eventListener;
	}
	return 1;
}

sub removeEventListener {
	my ($self, $event, $eventListener) = @_;
	if (defined $eventListener) {
		$eventListener->isa('Events::EventListener') or die("I need a Events::EventListener for $event");
	}
	if (ref($event) eq 'ARRAY') {
		foreach my $e (@{$event}) {
			delete $$self{$e}{$eventListener};
		}
	} elsif (ref($event) eq 'HASH') {
		foreach my $e (keys %{$event}) {
			$$event{$e}->isa('Events::EventListener') or die("I need a Events::EventListener for $e");
			delete $$self{$e}{$$event{$e}};
		}
	} else {
		delete $$self{$event}{$eventListener};
	}
	return 1;
}

sub broadcastEvent {
	#my ($self, $event, $data) = @_;
	my $self = shift;
	my $event = shift;
	my @listeners = (values %{$$self{$event}}, values %{$$self{ALL}});
	foreach my $listener (@listeners) {
		eval { $listener->receiveEvent($event, @_); };
		warn $@ if ($@);		
	}
}

1;