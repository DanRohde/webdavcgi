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
package Events::TestEventListener;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Events::EventListener );

sub register {
    my ( $self, $channel ) = @_;
    $channel->add( 'ALL', $self );
    return;
}

sub receive {
    my ( $self, $event, $data ) = @_;
    use Data::Dumper;
    print {*STDERR}
      "Events::TestEventListener: received event $event with data: "
      . Dumper($data)
      . ".\n";
    return;
}

1;
