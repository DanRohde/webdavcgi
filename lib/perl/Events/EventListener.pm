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
package Events::EventListener;

use strict;
use warnings;

our $VERSION = '2.0';

use CGI::Carp;

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    $self->{config} = shift;
    return $self;
}
sub free {
    my ($self) = @_;
    delete $self->{config};
    return $self;
}
sub register {

    # my ($self, $channel) = @_;
    carp 'overwrite me!';
    return;
}

sub receive {

    # my ($self, $event, $data) = @_;
    carp 'overwrite me!';
    return;
}
1;
